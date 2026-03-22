<template>
  <div>
    <header class="bg-white border-b border-gray-200">
      <div class="mx-auto max-w-7xl px-4 py-4 sm:px-6 lg:px-8">
        <NuxtLink
          to="/"
          class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700"
        >
          <ArrowLeft class="size-3" />
          Back to overview
        </NuxtLink>
      </div>
    </header>

    <main class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">
        Datenschutzerklärung
      </h1>
      <p class="text-sm text-gray-500 mb-8">Stand: März 2026</p>

      <div class="space-y-8 text-gray-700 leading-relaxed">
        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            1. Verantwortlicher
          </h2>
          <div class="rounded-lg bg-gray-50 p-4">
            <p>Enes Kayali</p>
            <p>Friedrich-Heene-Straße 7</p>
            <p>67061 Ludwigshafen am Rhein</p>
            <p>
              E-Mail:
              <a
                href="mailto:contact@indie-radar.com"
                class="text-blue-600 hover:underline"
                >contact@indie-radar.com</a
              >
            </p>
          </div>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            2. Art und Zweck der Datenverarbeitung
          </h2>
          <p>
            indie-radar.com ist eine öffentlich zugängliche
            Informationsdatenbank über SaaS-Produkte. Die Website aggregiert
            ausschließlich
            <strong>öffentlich verfügbare Unternehmensdaten</strong> aus
            folgenden Quelltypen:
          </p>
          <ul class="mt-2 list-disc pl-6 space-y-1">
            <li>Offizielle Unternehmenswebsites und Pressemitteilungen</li>
            <li>
              Öffentliche Datenbanken und APIs (z.B. TrustMRR, Crunchbase)
            </li>
            <li>Wikipedia und andere öffentliche Nachschlagewerke</li>
            <li>SEC Filings und öffentliche Finanzberichte</li>
          </ul>
          <p class="mt-2">
            Es werden
            <strong>keine personenbezogenen Daten von Privatpersonen</strong>
            gesammelt, verarbeitet oder gespeichert. Die dargestellten
            Informationen beziehen sich ausschließlich auf Unternehmen, Produkte
            und deren öffentlich bekannte Gründer/Geschäftsführer in deren
            Funktion als Unternehmensvertreter.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            3. Rechtsgrundlagen
          </h2>
          <p>
            Die Verarbeitung der dargestellten Unternehmensdaten erfolgt auf
            folgenden Rechtsgrundlagen:
          </p>
          <ul class="mt-2 list-disc pl-6 space-y-1">
            <li>
              <strong>Art. 6 Abs. 1 lit. f DSGVO</strong> (berechtigtes
              Interesse): Aggregation und Darstellung öffentlich verfügbarer
              Unternehmensinformationen zu Informationszwecken. Das berechtigte
              Interesse besteht in der Bereitstellung einer umfassenden,
              quellenbasierten SaaS-Datenbank.
            </li>
            <li>
              <strong>Art. 5 Abs. 1 GG</strong> (Informationsfreiheit): Die
              Daten stammen aus allgemein zugänglichen Quellen und werden im
              Rahmen der redaktionellen Berichterstattung dargestellt.
            </li>
          </ul>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            4. Darstellung von Gründer-/Geschäftsführer-Informationen
          </h2>
          <p>
            Die Darstellung von Namen, öffentlichen Social-Media-Handles und
            öffentlich verfügbaren Profilbildern von Gründern und
            Geschäftsführern erfolgt ausschließlich in deren Funktion als
            Unternehmensvertreter und basiert auf:
          </p>
          <ul class="mt-2 list-disc pl-6 space-y-1">
            <li>
              Öffentlich auf Social-Media-Plattformen (z.B. X/Twitter)
              verfügbaren Profilen
            </li>
            <li>Öffentlichen API-Daten von Plattformen wie TrustMRR</li>
            <li>Selbstveröffentlichten Unternehmensinformationen</li>
          </ul>
          <p class="mt-2">
            <strong>Recht auf Löschung:</strong> Betroffene Personen können
            jederzeit die Entfernung ihrer Daten per E-Mail an
            <a
              href="mailto:contact@indie-radar.com"
              class="text-blue-600 hover:underline"
              >contact@indie-radar.com</a
            >
            beantragen. Wir kommen berechtigten Löschungsanfragen unverzüglich
            nach.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            5. Hosting und technische Datenverarbeitung
          </h2>
          <p>
            Die Website wird auf <strong>Cloudflare Pages</strong> gehostet.
            Beim Zugriff auf die Website werden folgende technische Daten
            automatisch in Server-Logfiles gespeichert:
          </p>
          <ul class="mt-2 list-disc pl-6 space-y-1">
            <li>IP-Adresse (anonymisiert)</li>
            <li>Browsertyp und -version</li>
            <li>Betriebssystem</li>
            <li>Referrer URL</li>
            <li>Zeitpunkt des Zugriffs</li>
          </ul>
          <p class="mt-2">
            Die Verarbeitung erfolgt auf Grundlage von Art. 6 Abs. 1 lit. f
            DSGVO. Cloudflare ist unter dem EU-US Data Privacy Framework
            zertifiziert.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            6. Datenbankdienst (Supabase)
          </h2>
          <p>
            Wir nutzen <strong>Supabase</strong> als Datenbank-Backend. In der
            Datenbank werden ausschließlich Produktdaten (keine
            personenbezogenen Nutzerdaten) gespeichert. Supabase-Server befinden
            sich in der EU.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            7. Cookies und Tracking
          </h2>
          <p>
            Diese Website verwendet
            <strong
              >keine Tracking-Cookies, keine Analytics-Tools und kein
              Nutzer-Tracking</strong
            >. Es werden keine Nutzerprofile erstellt und keine Daten an Dritte
            zu Werbezwecken weitergegeben.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            8. Quellenangaben und Transparenz
          </h2>
          <p>
            Jeder auf dieser Website dargestellte Datenpunkt ist mit seiner
            Originalquelle verknüpft. Wir verwenden ein Trust-Level-System
            (0–100), um die Zuverlässigkeit der Quellen transparent zu
            kennzeichnen. Nutzer können jederzeit die Originalquelle eines
            Datenpunkts einsehen und verifizieren.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            9. Ihre Rechte nach DSGVO
          </h2>
          <p>
            Soweit personenbezogene Daten betroffen sind, stehen Ihnen folgende
            Rechte zu:
          </p>
          <ul class="mt-2 list-disc pl-6 space-y-1">
            <li><strong>Auskunft</strong> (Art. 15 DSGVO)</li>
            <li><strong>Berichtigung</strong> (Art. 16 DSGVO)</li>
            <li><strong>Löschung</strong> (Art. 17 DSGVO)</li>
            <li>
              <strong>Einschränkung der Verarbeitung</strong> (Art. 18 DSGVO)
            </li>
            <li><strong>Widerspruch</strong> (Art. 21 DSGVO)</li>
            <li><strong>Datenübertragbarkeit</strong> (Art. 20 DSGVO)</li>
          </ul>
          <p class="mt-2">
            Anfragen richten Sie bitte an:
            <a
              href="mailto:contact@indie-radar.com"
              class="text-blue-600 hover:underline"
              >contact@indie-radar.com</a
            >
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            10. Beschwerderecht
          </h2>
          <p>
            Sie haben das Recht, sich bei einer Datenschutz-Aufsichtsbehörde zu
            beschweren. Die zuständige Aufsichtsbehörde ist:
          </p>
          <div class="mt-2 rounded-lg bg-gray-50 p-4">
            <p>
              Der Landesbeauftragte für den Datenschutz und die
              Informationsfreiheit Rheinland-Pfalz
            </p>
            <p>Postfach 30 40</p>
            <p>55020 Mainz</p>
          </div>
        </section>

        <section>
          <h2 class="text-xl font-bold text-gray-900 mb-3">
            11. Hinweis für Unternehmen
          </h2>
          <p>
            Sind Sie Vertreter eines auf dieser Website gelisteten Unternehmens
            und möchten Informationen korrigieren, ergänzen oder entfernen
            lassen? Kontaktieren Sie uns unter
            <a
              href="mailto:contact@indie-radar.com"
              class="text-blue-600 hover:underline"
              >contact@indie-radar.com</a
            >. Wir bearbeiten berechtigte Anfragen zeitnah.
          </p>
        </section>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ArrowLeft } from "lucide-vue-next";

useHead({
  title: "Datenschutzerklärung — IndieRadar",
  meta: [
    {
      name: "description",
      content: "Datenschutzerklärung von indie-radar.com — DSGVO-konform",
    },
  ],
});
</script>
