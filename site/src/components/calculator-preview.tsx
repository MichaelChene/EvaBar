import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";

const examples = [
  { id: "split-bill", label: "Split a bill", expression: "(128.40 * 1.2) / 3", result: "51.36" },
  { id: "square-root", label: "Use a function", expression: "sqrt(144) + 3", result: "15" },
  { id: "annual-budget", label: "Plan a budget", expression: "3250 * 12 + 1050", result: "40,050" },
];

const appearances = [
  { id: "liquid-glass", label: "Liquid Glass" },
  { id: "classic", label: "Classic" },
] as const;

const defaultAppearance = appearances[0].id;

function previewImageUrl(appearance: string, example: string) {
  return `/images/desktop-preview/${appearance}-${example}.webp`;
}

export function CalculatorPreview() {
  const [selected, setSelected] = useState(0);
  const [appearance, setAppearance] = useState<(typeof appearances)[number]["id"]>(defaultAppearance);
  const [copyFeedback, setCopyFeedback] = useState<{ index: number; status: "copied" | "unavailable" }>();
  const example = examples[selected];
  const feedback = copyFeedback?.index === selected ? copyFeedback.status : undefined;

  useEffect(() => {
    const controller = new AbortController();
    const initialUrl = previewImageUrl(defaultAppearance, examples[0].id);

    function preloadAlternates() {
      if (controller.signal.aborted) return;
      for (const { id: appearanceId } of appearances) {
        for (const { id: exampleId } of examples) {
          const url = previewImageUrl(appearanceId, exampleId);
          if (url === initialUrl) continue;

          const image = new Image();
          image.fetchPriority = "low";
          image.src = url;
        }
      }
    }

    async function schedulePreload() {
      await document.fonts.ready;
      if (controller.signal.aborted) return;

      if (typeof window.requestIdleCallback === "function") {
        window.requestIdleCallback(preloadAlternates);
      } else {
        window.setTimeout(preloadAlternates, 250);
      }
    }

    if (document.readyState === "complete") {
      void schedulePreload();
    } else {
      window.addEventListener("load", schedulePreload, { once: true, signal: controller.signal });
    }
    return () => controller.abort();
  }, []);

  async function copyResult() {
    try {
      await navigator.clipboard.writeText(example.result);
      setCopyFeedback({ index: selected, status: "copied" });
    } catch {
      setCopyFeedback({ index: selected, status: "unavailable" });
    }
  }

  return (
    <figure className="calculator-preview" aria-label="EvaBar interactive preview">
      <div className="desktop-preview" data-appearance={appearance}>
        <img
          className="desktop-preview-panel"
          src={previewImageUrl(appearance, example.id)}
          width="2336"
          height="144"
          alt=""
        />
        <button className="demo-copy" type="button" onClick={copyResult} aria-label="Copy result" title="Copy result" />
      </div>
      <div className="demo-readout">
        <code>{example.expression}</code>
        <output aria-label="Expression result">{example.result}</output>
      </div>
      <figcaption className="demo-caption">
        <div className="demo-appearance" aria-label="Preview appearance" role="group">
          {appearances.map(({ id, label }) => (
            <Button key={id} type="button" size="sm" variant="ghost" aria-pressed={appearance === id}
              onClick={() => setAppearance(id)}>
              {label}
            </Button>
          ))}
        </div>
        <div className="demo-examples" aria-label="Calculation examples" role="group">
          <span className="demo-label" aria-hidden="true">Try an example</span>
          {examples.map((sample, index) => (
            <Button
              key={sample.id}
              type="button"
              size="sm"
              variant="ghost"
              aria-pressed={index === selected}
              className="example-button"
              onClick={() => {
                setCopyFeedback(undefined);
                setSelected(index);
              }}
            >
              {sample.label}
            </Button>
          ))}
        </div>
        <span className="demo-feedback" role="status">
          {feedback === "copied" && "Copied"}
          {feedback === "unavailable" && "Clipboard unavailable"}
        </span>
      </figcaption>
    </figure>
  );
}
