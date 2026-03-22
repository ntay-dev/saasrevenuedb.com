-- Migration 00009: Auto-categorize products via keyword matching
-- Also: fix German category names → English, add Russian country normalization

-- ============================================================
-- 1. Fix German category names in lookup table
-- ============================================================
UPDATE categories SET name = 'Collaboration', slug = 'collaboration' WHERE slug = 'kollaboration';
UPDATE categories SET name = 'Communication', slug = 'communication' WHERE slug = 'kommunikation';
UPDATE categories SET name = 'Productivity', slug = 'productivity' WHERE name = 'Produktivität';
UPDATE categories SET name = 'Project Management', slug = 'project-management' WHERE slug = 'projektmanagement';

-- Also fix any existing data points referencing old German names
UPDATE product_data_points SET field_value = 'Collaboration'
WHERE field_name = 'category_name' AND field_value = 'Kollaboration' AND is_current = true;
UPDATE product_data_points SET field_value = 'Communication'
WHERE field_name = 'category_name' AND field_value = 'Kommunikation' AND is_current = true;
UPDATE product_data_points SET field_value = 'Productivity'
WHERE field_name = 'category_name' AND field_value IN ('Produktivität', 'Productivity') AND is_current = true;
UPDATE product_data_points SET field_value = 'Project Management'
WHERE field_name = 'category_name' AND field_value = 'Projektmanagement' AND is_current = true;

-- ============================================================
-- 2. Fix Russian country name → United States
-- ============================================================
UPDATE countries SET name_en = 'United States', name_de = 'Vereinigte Staaten'
WHERE name_en = 'Соединённые Штаты Америки' OR name_de = 'Соединённые Штаты Америки';

-- Also add to product data points
UPDATE product_data_points SET field_value = 'US'
WHERE field_name = 'country' AND field_value IN ('Соединённые Штаты Америки', 'Estados Unidos de América', 'Estados Unidos') AND is_current = true;

-- ============================================================
-- 3. Auto-categorize function: keyword-based matching
-- ============================================================
CREATE OR REPLACE FUNCTION auto_categorize_products()
RETURNS TABLE(categorized_count int, already_categorized int, no_match int) AS $$
DECLARE
  v_categorized int := 0;
  v_already int := 0;
  v_no_match int := 0;
  v_product RECORD;
  v_matched_category text := NULL;
  v_text text;
BEGIN
  -- Loop through uncategorized products (use product's original source)
  FOR v_product IN
    SELECT sp.id, sp.slug, sp.name,
           (SELECT pdp.field_value FROM product_data_points pdp
            WHERE pdp.product_id = sp.id AND pdp.field_name = 'description' AND pdp.is_current = true
            LIMIT 1) as description,
           (SELECT pdp.source_id FROM product_data_points pdp
            WHERE pdp.product_id = sp.id AND pdp.field_name = 'company' AND pdp.is_current = true
            LIMIT 1) as original_source_id
    FROM saas_products sp
    WHERE NOT EXISTS (
      SELECT 1 FROM product_data_points pdp
      WHERE pdp.product_id = sp.id
        AND pdp.field_name = 'category_name'
        AND pdp.is_current = true
        AND pdp.field_value IS NOT NULL
        AND pdp.field_value != ''
    )
  LOOP
    -- Combine name + description for matching (lowercase)
    v_text := lower(coalesce(v_product.name, '') || ' ' || coalesce(v_product.description, ''));
    v_matched_category := NULL;

    -- Priority-ordered keyword matching (most specific first)
    -- Each WHEN checks for strong signal keywords

    -- AI & Machine Learning (most common, check first)
    IF v_text ~ '\m(chatgpt|openai|llm|gpt-[34]|large language|machine learning|deep learning|neural net|computer vision|nlp |natural language processing|ai[- ]powered|ai[- ]driven|ai[- ]based|artificial intelligence|generative ai|ai assistant|ai agent|ai tool|ai model|ai chatbot|ai writing|ai image|ai video|ai voice|ai content|ai copilot|ai coach|ai tutor)\M'
    THEN v_matched_category := 'Artificial Intelligence';

    -- Developer Tools
    ELSIF v_text ~ '\m(api |sdk |cli |devtool|developer tool|github|gitlab|bitbucket|docker|kubernetes|ci/cd|continuous integration|code review|code editor|ide |debugging|testing framework|unit test|deployment|devops|serverless|database tool|sql client|git |version control|code generation|developer platform|npm |pip |package manager|terminal|command line|open.?source tool|backend|frontend framework|web framework|static site|jamstack|headless)\M'
    THEN v_matched_category := 'Developer Tools';

    -- E-Commerce
    ELSIF v_text ~ '\m(e-?commerce|shopify|woocommerce|online store|online shop|dropshipping|product listing|shopping cart|checkout|payment gateway|merchant|retail tech|point of sale|pos system|inventory management|order management|fulfillment|amazon seller|ebay|etsy seller|print on demand|d2c|direct to consumer)\M'
    THEN v_matched_category := 'E-Commerce';

    -- FinTech & Payment
    ELSIF v_text ~ '\m(fintech|financial technology|banking app|neobank|payment processing|stripe|paypal|invoice|invoicing|bookkeeping|expense tracking|expense management|budgeting app|personal finance|investment|trading platform|stock|cryptocurrency trading|crypto exchange|defi|decentralized finance|lending platform|credit|insurance tech|insurtech|tax software|tax filing|accounting software|quickbooks|xero)\M'
    THEN v_matched_category := 'FinTech';

    -- Marketing
    ELSIF v_text ~ '\m(marketing tool|marketing platform|marketing automation|email marketing|email campaign|newsletter|seo tool|seo platform|search engine optimization|keyword research|backlink|link building|content marketing|inbound marketing|outbound marketing|growth hacking|conversion rate|landing page builder|a/b test|split test|attribution|utm|google ads|facebook ads|ad campaign|ad manager|ppc|pay per click|affiliate marketing|influencer marketing|brand monitoring|marketing analytics)\M'
    THEN v_matched_category := 'Marketing';

    -- Sales & CRM
    ELSIF v_text ~ '\m(crm|customer relationship|sales tool|sales platform|sales automation|sales pipeline|lead generation|lead gen|lead scoring|cold email|cold outreach|outreach tool|prospecting|sales engagement|sales enablement|deal flow|pipeline management|b2b sales|sales intelligence|revenue operations|revops|salesforce|hubspot|close deals|closing deals)\M'
    THEN v_matched_category := 'Sales';

    -- Education & Learning
    ELSIF v_text ~ '\m(education|learning platform|online course|e-learning|elearning|lms |learning management|teaching|tutoring|tutor |student|edtech|ed-tech|flashcard|study |quiz platform|exam prep|language learning|skill development|training platform|certification|mooc|bootcamp|coding bootcamp|educational|school management|classroom|curriculum)\M'
    THEN v_matched_category := 'Education';

    -- Health & Fitness
    ELSIF v_text ~ '\m(fitness|workout|exercise app|gym |health tracking|health app|wellness|meditation|mental health|therapy app|therapist|nutrition|diet |calorie|weight loss|yoga|personal trainer|health coach|sleep tracking|habit tracker|mindfulness|self-care|wellbeing|well-being|healthcare patient|telehealth|telemedicine)\M'
    THEN v_matched_category := 'Health & Fitness';

    -- Healthcare (clinical/medical, distinct from fitness)
    ELSIF v_text ~ '\m(healthcare|health care|medical software|clinical|ehr |emr |electronic health|electronic medical|patient management|hospital|pharmacy|medical device|medical practice|hipaa|health information|medical billing|medical record|diagnostics|biotech|pharmaceutical|drug discovery|clinical trial)\M'
    THEN v_matched_category := 'Healthcare';

    -- Design
    ELSIF v_text ~ '\m(design tool|graphic design|ui design|ux design|web design|logo design|brand design|figma|sketch app|canva|design system|prototyping|wireframe|mockup|illustration|icon pack|font |typography|photo editing|image editing|video editing|3d design|3d modeling|animation tool|motion design|design agency|creative tool|design template)\M'
    THEN v_matched_category := 'Design';

    -- Content Creation
    ELSIF v_text ~ '\m(content creation|content creator|blogging|blog platform|writing tool|copywriting|copy tool|text generator|article writer|content writer|podcast|podcasting|video creation|video maker|youtube|video platform|streaming tool|screen recording|screen capture|screenshot|social media content|content calendar|editorial|publishing platform|wordpress theme|wordpress plugin|cms theme|headless cms)\M'
    THEN v_matched_category := 'Content Creation';

    -- Analytics & Data
    ELSIF v_text ~ '\m(analytics|web analytics|data analytics|business intelligence|bi tool|dashboard|data visualization|reporting tool|metrics|kpi |tracking pixel|event tracking|user analytics|product analytics|heatmap|session recording|funnel analysis|cohort|data pipeline|etl |data warehouse|data integration|google analytics alternative|mixpanel|amplitude|plausible|fathom)\M'
    THEN v_matched_category := 'Analytics';

    -- Social Media
    ELSIF v_text ~ '\m(social media|twitter tool|x.com tool|linkedin tool|instagram tool|tiktok|social network|social platform|social scheduling|social posting|social management|social listening|social monitoring|hashtag|follower|social proof|user generated content|ugc|community platform|community management|forum software|discord bot|slack bot|social commerce)\M'
    THEN v_matched_category := 'Social Media';

    -- Project Management
    ELSIF v_text ~ '\m(project management|task management|todo |to-do|kanban|agile |scrum |sprint planning|project planning|project tracking|team management|work management|workflow|issue tracker|bug tracker|jira|trello|asana|notion|basecamp|roadmap tool|gantt|time tracking|timesheet|resource management)\M'
    THEN v_matched_category := 'Project Management';

    -- Productivity
    ELSIF v_text ~ '\m(productivity|note.?taking|note app|knowledge base|wiki |personal knowledge|second brain|bookmarking|read later|clipboard|password manager|calendar app|scheduling|appointment|meeting scheduler|email client|email app|inbox|file management|document management|pdf tool|spreadsheet|form builder|survey tool|automation tool|zapier|make.com|integromat|workflow automation)\M'
    THEN v_matched_category := 'Productivity';

    -- Customer Support
    ELSIF v_text ~ '\m(customer support|customer service|help desk|helpdesk|ticketing|live chat|chatbot|chat widget|intercom|zendesk|freshdesk|knowledge base for customers|faq |feedback tool|customer feedback|nps |net promoter|user feedback|bug report|feature request|support ticket|customer success|onboarding tool|user onboarding)\M'
    THEN v_matched_category := 'Customer Support';

    -- HR & Recruiting
    ELSIF v_text ~ '\m(hr |human resource|recruiting|recruitment|hiring|job board|applicant tracking|ats |talent management|employee engagement|payroll|benefits|onboarding employee|performance review|people management|workforce|staffing|resume|cv builder|job listing|career page|employee experience|hris)\M'
    THEN v_matched_category := 'HR';

    -- Security
    ELSIF v_text ~ '\m(security|cybersecurity|cyber security|vpn |encryption|firewall|malware|antivirus|vulnerability|penetration testing|pentest|identity management|authentication|oauth|sso |single sign|two-factor|2fa |mfa |access control|data protection|privacy tool|gdpr|compliance tool|audit log|security monitoring|threat detection|siem)\M'
    THEN v_matched_category := 'Security';

    -- No-Code / Low-Code
    ELSIF v_text ~ '\m(no-?code|low-?code|drag and drop|drag.n.drop|visual builder|website builder|app builder|form builder|page builder|site builder|webflow|bubble\.io|airtable|retool|internal tool|admin panel builder|without coding|no coding|build without code)\M'
    THEN v_matched_category := 'No-Code';

    -- Communication & Collaboration
    ELSIF v_text ~ '\m(team communication|team chat|video conferencing|video call|screen sharing|whiteboard|collaboration tool|real-?time collaboration|remote work|remote team|virtual office|async communication|messaging app|voice call|voip|webinar|virtual meeting|online meeting|zoom alternative)\M'
    THEN v_matched_category := 'Collaboration';

    -- Games & Gaming
    ELSIF v_text ~ '\m(game |gaming|video game|mobile game|game development|game engine|unity |unreal engine|game design|esports|game server|game studio|indie game|board game|card game|puzzle game|rpg |mmorpg|game monetization)\M'
    THEN v_matched_category := 'Games';

    -- Real Estate
    ELSIF v_text ~ '\m(real estate|property management|rental|landlord|tenant|mortgage|home buying|home selling|real estate agent|realtor|property listing|mls |house hunting|apartment|commercial real estate|proptech|property tech)\M'
    THEN v_matched_category := 'Real Estate';

    -- Travel
    ELSIF v_text ~ '\m(travel|booking|hotel|flight|airbnb|vacation|tourism|trip planning|itinerary|travel agent|travel tech|hospitality|restaurant management|food delivery|food ordering|reservation)\M'
    THEN v_matched_category := 'Travel';

    -- Marketplace
    ELSIF v_text ~ '\m(marketplace|two-sided|two sided|connect buyers|connect sellers|peer to peer|p2p platform|gig economy|freelance marketplace|service marketplace|rental marketplace|listing platform|classifieds|directory)\M'
    THEN v_matched_category := 'Marketplace';

    -- Crypto & Web3
    ELSIF v_text ~ '\m(crypto|blockchain|web3|nft |token|smart contract|ethereum|bitcoin|solana|defi|decentralized|dao |wallet|mining|staking|yield farming)\M'
    THEN v_matched_category := 'Crypto & Web3';

    -- Legal
    ELSIF v_text ~ '\m(legal tech|legaltech|contract management|contract signing|e-?signature|digital signature|law firm|legal document|legal practice|compliance management|regulatory|terms of service generator|privacy policy generator|trademark|patent|intellectual property)\M'
    THEN v_matched_category := 'Legal';

    -- Logistics & Supply Chain
    ELSIF v_text ~ '\m(logistics|shipping|delivery|fleet management|supply chain|warehouse|freight|trucking|courier|last mile|route optimization|tracking shipment|order fulfillment|3pl)\M'
    THEN v_matched_category := 'Logistics';

    -- Mobile Apps (generic mobile-focused)
    ELSIF v_text ~ '\m(mobile app|ios app|android app|app store|play store|push notification|mobile sdk|react native|flutter app|swift app|kotlin app|mobile development|app development|mobile-first)\M'
    THEN v_matched_category := 'Mobile Apps';

    -- Monitoring & DevOps
    ELSIF v_text ~ '\m(monitoring|uptime|status page|incident management|alerting|observability|log management|error tracking|apm |application performance|server monitoring|infrastructure monitoring|site reliability|sre |pagerduty|datadog|sentry)\M'
    THEN v_matched_category := 'Monitoring';

    -- Cloud Infrastructure
    ELSIF v_text ~ '\m(cloud hosting|web hosting|cloud infrastructure|aws |azure|google cloud|cloud storage|cdn |cloud computing|iaas|paas|managed hosting|vps |dedicated server|cloud migration|cloud native)\M'
    THEN v_matched_category := 'Cloud Infrastructure';

    -- Automation
    ELSIF v_text ~ '\m(automation|automate|robotic process|rpa |workflow engine|business process|bpm |process automation|task automation|automated workflow|integration platform|ipaas|connector|middleware)\M'
    THEN v_matched_category := 'Automation';

    -- Entertainment
    ELSIF v_text ~ '\m(entertainment|music app|music streaming|movie|film|tv show|media streaming|audio|sound|radio|creative writing|storytelling|fiction|comic|manga|anime)\M'
    THEN v_matched_category := 'Entertainment';

    -- News & Magazines
    ELSIF v_text ~ '\m(news |news aggregat|magazine|journalism|media outlet|newsletter platform|rss |feed reader|curated content|press release|media monitoring|news feed)\M'
    THEN v_matched_category := 'News & Magazines';

    -- Catch-all: SaaS (if mentions SaaS/subscription but doesn't fit elsewhere)
    ELSIF v_text ~ '\m(saas |software as a service|subscription management|subscription billing|recurring billing|saas boilerplate|saas template|saas starter|micro-?saas)\M'
    THEN v_matched_category := 'SaaS';

    -- Utilities (generic tools)
    ELSIF v_text ~ '\m(browser extension|chrome extension|firefox extension|utility|converter|calculator|generator tool|url shortener|qr code|file converter|data extraction|web scraping|scraper|proxy|vpn service|dns |domain name|whois|sitemap generator|backup tool|migration tool)\M'
    THEN v_matched_category := 'Utilities';

    -- === PASS 2: Broader patterns for remaining products ===

    -- Broader AI (mentions "ai" with action verbs)
    ELSIF v_text ~ '\mai\M' AND v_text ~ '\m(generat|writ|creat|assist|bot|chat|model|train|predict|automat|smart|intelligen)\M'
    THEN v_matched_category := 'Artificial Intelligence';

    -- Broader Marketing/SEO
    ELSIF v_text ~ '\m(seo|grow|audience|traffic|brand|promot|advertis|campaign|reach|engag|viral|organic|rank|visib)\M'
    THEN v_matched_category := 'Marketing';

    -- Broader Sales
    ELSIF v_text ~ '\m(lead|prospect|close|deal|revenue|b2b|sales|sell|pitch|proposal|outreach|pipeline)\M'
    THEN v_matched_category := 'Sales';

    -- Broader E-Commerce
    ELSIF v_text ~ '\m(shop|store|buy|purchase|cart|order|product|retail|sell online|ecommerce|commerce)\M'
    THEN v_matched_category := 'E-Commerce';

    -- Broader Education
    ELSIF v_text ~ '\m(learn|teach|course|lesson|skill|knowledge|train|mentor|coach|academy|class|workshop)\M'
    THEN v_matched_category := 'Education';

    -- Broader Content Creation
    ELSIF v_text ~ '\m(blog|write|content|publish|article|post|story|creat|author|editor|media|video|photo|image)\M'
    THEN v_matched_category := 'Content Creation';

    -- Broader FinTech
    ELSIF v_text ~ '\m(money|financ|pay|pric|billing|charg|subscript|revenue|profit|earn|income|saving|budget|bank|fund|invest)\M'
    THEN v_matched_category := 'FinTech';

    -- Broader Productivity
    ELSIF v_text ~ '\m(organiz|manage|schedul|plan|track|remind|note|document|template|workflow|efficien|productiv|time|task|list)\M'
    THEN v_matched_category := 'Productivity';

    -- Broader Developer Tools
    ELSIF v_text ~ '\m(code|develop|program|software|tech|debug|deploy|server|hosting|cloud|database|integrat)\M'
    THEN v_matched_category := 'Developer Tools';

    -- Broader Design
    ELSIF v_text ~ '\m(design|visual|ui|ux|layout|style|theme|color|pixel|responsive|beauti|creativ)\M'
    THEN v_matched_category := 'Design';

    -- Broader Social Media
    ELSIF v_text ~ '\m(social|communit|network|connect|share|follow|friend|group|member|chat|messag|forum)\M'
    THEN v_matched_category := 'Social Media';

    -- Broader Health
    ELSIF v_text ~ '\m(health|fit|well|diet|sleep|stress|mind|body|medic|care|therap|doctor|patient)\M'
    THEN v_matched_category := 'Health & Fitness';

    -- Broader No-Code
    ELSIF v_text ~ '\m(build|builder|creat|website|web app|webapp|site|page|template|drag|drop|visual|easy|simple|fast)\M' AND v_text ~ '\m(no code|without code|anyone can|non-?technical|no programming)\M'
    THEN v_matched_category := 'No-Code';

    -- Broader Customer Support
    ELSIF v_text ~ '\m(support|help|service|ticket|feedback|review|rating|satisf|respond|resolve)\M'
    THEN v_matched_category := 'Customer Support';

    -- Final catch-all: anything with a description gets "SaaS"
    ELSIF v_product.description IS NOT NULL AND v_product.description != ''
    THEN v_matched_category := 'SaaS';

    END IF;

    IF v_matched_category IS NOT NULL AND v_product.original_source_id IS NOT NULL THEN
      -- Insert category_name data point using the product's original source
      INSERT INTO product_data_points (product_id, field_name, field_value, source_id, sourced_at, is_current)
      VALUES (v_product.id, 'category_name', v_matched_category, v_product.original_source_id, now(), true)
      ON CONFLICT DO NOTHING;
      v_categorized := v_categorized + 1;
    ELSE
      v_no_match := v_no_match + 1;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_categorized, v_already, v_no_match;
END;
$$ LANGUAGE plpgsql;
