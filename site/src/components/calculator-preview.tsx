import { BatteryFull, Check, Copy, Ellipsis, LockKeyholeOpen, Wifi } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/button";

const examples = [
  { label: "Split a bill", expression: "(128.40 * 1.2) / 3", result: "51.36" },
  { label: "Use a function", expression: "sqrt(144) + 3", result: "15" },
  { label: "Plan a budget", expression: "3250 * 12 + 1050", result: "40050" },
];

export function CalculatorPreview() {
  const [selected, setSelected] = useState(0);
  const [copyFeedback, setCopyFeedback] = useState<{ index: number; status: "copied" | "unavailable" }>();
  const example = examples[selected];
  const feedback = copyFeedback?.index === selected ? copyFeedback.status : undefined;

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
      <div className="desktop-preview desktop-wallpaper">
        <div className="desktop-menubar" aria-hidden="true">
          <span className="desktop-app">EvaBar</span>
          <span className="desktop-status"><img src="/images/evabar-mark.png" alt="" width="14" height="14" /><Wifi size={13} /><BatteryFull size={16} /><span>9:41 AM</span></span>
        </div>
        <div className="demo-calculator">
          <div className="demo-tools" aria-hidden="true">
            <Ellipsis size={19} />
            <LockKeyholeOpen size={16} />
            <img src="/images/evabar-mark.png" alt="" width="19" height="19" />
          </div>
          <code className="demo-expression">{example.expression}</code>
          <div className="demo-answer">
            <output className="demo-result" aria-label="Expression result">{example.result}</output>
            <Button type="button" size="icon" variant="ghost" onClick={copyResult} aria-label="Copy result" title="Copy result" className="demo-copy">
              {feedback === "copied" ? <Check aria-hidden="true" /> : <Copy aria-hidden="true" />}
            </Button>
          </div>
        </div>
      </div>
      <figcaption className="demo-caption">
        <span className="demo-label">Try an example</span>
        <div className="demo-examples" aria-label="Calculation examples" role="group">
          {examples.map((sample, index) => (
            <Button
              key={sample.label}
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
