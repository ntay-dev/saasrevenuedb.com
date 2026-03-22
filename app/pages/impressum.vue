<template>
  <div>
    <div class="border-b border-(--color-border) bg-(--color-surface)">
      <div class="mx-auto max-w-7xl px-4 py-4 sm:px-6 lg:px-8">
        <NuxtLink
          to="/"
          class="inline-flex items-center gap-1 text-sm text-(--color-text-muted) transition-colors hover:text-(--color-text-secondary)"
        >
          <ArrowLeft class="size-3" />
          Back
        </NuxtLink>
      </div>
    </div>

    <main class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
      <h1 class="text-3xl font-bold text-(--color-text-primary) mb-2">
        Impressum
      </h1>
      <p class="text-sm text-(--color-text-muted) mb-8">
        Angaben gemäß § 5 DDG und § 18 Abs. 2 MStV
      </p>

      <div class="space-y-8 text-(--color-text-secondary) leading-relaxed">
        <section>
          <h2 class="text-xl font-bold text-(--color-text-primary) mb-3">
            Betreiber der Website
          </h2>
          <div
            class="rounded-xl bg-(--color-surface-elevated) border border-(--color-border) p-4"
          >
            <p>Enes Kayali</p>
            <p>Friedrich-Heene-Straße 7</p>
            <p>67061 Ludwigshafen am Rhein</p>
            <p>Deutschland</p>
          </div>
        </section>

        <section>
          <h2 class="text-xl font-bold text-(--color-text-primary) mb-3">
            Kontakt
          </h2>
          <div
            class="rounded-xl bg-(--color-surface-elevated) border border-(--color-border) p-4"
          >
            <p>
              E-Mail:
              <a
                href="mailto:contact@indie-radar.com"
                class="text-blue-400 hover:underline"
                >contact@indie-radar.com</a
              >
            </p>
          </div>
        </section>

        <section>
          <h2 class="text-xl font-bold text-(--color-text-primary) mb-3">
            Umsatzsteuer-Identifikationsnummer
          </h2>
          <p>Umsatzsteuer-Identifikationsnummer gemäß § 27a UStG:</p>
          <p class="mt-1 font-medium">
            Beantragt, wird nach Erteilung ergänzt.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-(--color-text-primary) mb-3">
            Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV
          </h2>
          <div
            class="rounded-xl bg-(--color-surface-elevated) border border-(--color-border) p-4"
          >
            <p>Enes Kayali</p>
            <p>Friedrich-Heene-Straße 7</p>
            <p>67061 Ludwigshafen am Rhein</p>
          </div>
        </section>

        <section>
          <h2 class="text-xl font-bold text-(--color-text-primary) mb-3">
            Haftungsausschluss
          </h2>

          <h3
            class="text-lg font-semibold text-(--color-text-primary) mt-4 mb-2"
          >
            Haftung für Inhalte
          </h3>
          <p>
            Die Inhalte unserer Seiten wurden mit größter Sorgfalt erstellt. Für
            die Richtigkeit, Vollständigkeit und Aktualität der Inhalte können
            wir jedoch keine Gewähr übernehmen. Als Diensteanbieter sind wir
            gemäß § 7 Abs. 1 DDG für eigene Inhalte auf diesen Seiten nach den
            allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10 DDG sind wir
            als Diensteanbieter jedoch nicht verpflichtet, übermittelte oder
            gespeicherte fremde Informationen zu überwachen.
          </p>
          <p class="mt-2">
            Die auf dieser Website dargestellten Daten zu SaaS-Produkten stammen
            aus öffentlich zugänglichen Quellen und werden automatisiert
            aggregiert. Wir erheben keinen Anspruch auf Vollständigkeit oder
            Richtigkeit der dargestellten Informationen. Jeder Datenpunkt ist
            mit seiner Quelle versehen.
          </p>

          <h3
            class="text-lg font-semibold text-(--color-text-primary) mt-4 mb-2"
          >
            Haftung für Links
          </h3>
          <p>
            Unser Angebot enthält Links zu externen Websites Dritter, auf deren
            Inhalte wir keinen Einfluss haben. Für die Inhalte der verlinkten
            Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten
            verantwortlich.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-(--color-text-primary) mb-3">
            Urheberrecht
          </h2>
          <p>
            Die auf dieser Website dargestellten Produktnamen, Logos und Marken
            sind Eigentum der jeweiligen Unternehmen. Die Nutzung erfolgt
            ausschließlich zu Informationszwecken im Rahmen der redaktionellen
            Berichterstattung (§ 51 UrhG, Art. 5 Abs. 1 GG). Es wird keine
            geschäftliche Verbindung zu den dargestellten Unternehmen
            impliziert.
          </p>
          <p class="mt-2">
            Die durch den Seitenbetreiber erstellten Inhalte und Werke auf
            diesen Seiten unterliegen dem deutschen Urheberrecht. Beiträge
            Dritter sind als solche gekennzeichnet.
          </p>
        </section>

        <section>
          <h2 class="text-xl font-bold text-(--color-text-primary) mb-3">
            Streitschlichtung
          </h2>
          <p>
            Die Europäische Kommission stellt eine Plattform zur
            Online-Streitbeilegung (OS) bereit. Wir sind nicht bereit oder
            verpflichtet, an Streitbeilegungsverfahren vor einer
            Verbraucherschlichtungsstelle teilzunehmen.
          </p>
        </section>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ArrowLeft } from "lucide-vue-next";

useHead({
  title: "Impressum — IndieRadar",
  meta: [
    {
      name: "description",
      content: "Impressum von indie-radar.com — Angaben gemäß § 5 DDG",
    },
  ],
});
</script>
