import { useEffect, useRef, useState } from "react";
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

type Appearance = (typeof appearances)[number]["id"];
type PreviewSelection = { appearance: Appearance; selected: number };

const initialPreview: PreviewSelection = { appearance: appearances[0].id, selected: 0 };

function previewImageUrl(appearance: Appearance, example: string) {
  return `/images/desktop-preview/${appearance}-${example}.webp`;
}

const previewUrls = appearances.flatMap(({ id: appearance }) =>
  examples.map(({ id: example }) => previewImageUrl(appearance, example)),
);
const initialUrl = previewImageUrl(initialPreview.appearance, examples[0].id);

export function CalculatorPreview() {
  const [{ appearance, selected }, setPreview] = useState(initialPreview);
  const displayedPreview = useRef(initialPreview);
  const requestedPreview = useRef(initialPreview);
  const desktop = useRef<HTMLDivElement>(null);
  const [copyFeedback, setCopyFeedback] = useState<{ index: number; status: "copied" | "unavailable" }>();
  const example = examples[selected];
  const activeUrl = previewImageUrl(appearance, example.id);
  const feedback = copyFeedback?.index === selected ? copyFeedback.status : undefined;

  useEffect(() => {
    for (const image of desktop.current?.querySelectorAll<HTMLImageElement>("img[hidden]") ?? []) {
      void image.decode().catch(() => {});
    }
  }, []);

  async function showPreview(nextAppearance: Appearance, nextExample: number) {
    const url = previewImageUrl(nextAppearance, examples[nextExample].id);
    const image = desktop.current?.querySelector<HTMLImageElement>(`img[src="${url}"]`);
    if (!image) return;

    const next = { appearance: nextAppearance, selected: nextExample };
    requestedPreview.current = next;
    try {
      await image.decode();
    } catch {
      if (requestedPreview.current === next) requestedPreview.current = displayedPreview.current;
      return;
    }

    if (requestedPreview.current === next) {
      displayedPreview.current = next;
      setPreview(next);
    }
  }

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
      <div ref={desktop} className="desktop-preview" data-appearance={appearance}>
        {previewUrls.map((url) => (
          <img
            key={url}
            className="desktop-preview-panel"
            src={url}
            loading="eager"
            fetchPriority={url === initialUrl ? "high" : "low"}
            hidden={url !== activeUrl}
            width="2336"
            height="144"
            alt=""
          />
        ))}
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
              onClick={() => void showPreview(id, requestedPreview.current.selected)}>
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
                void showPreview(requestedPreview.current.appearance, index);
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
