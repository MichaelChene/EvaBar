import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";

export function FAQ() {
  return (
    <Accordion type="single" collapsible className="faq-list">
      <AccordionItem value="compatibility">
        <AccordionTrigger>Which Macs can run EvaBar?</AccordionTrigger>
        <AccordionContent>The current release requires macOS 13 or later and a Mac with Apple silicon.</AccordionContent>
      </AccordionItem>
      <AccordionItem value="expressions">
        <AccordionTrigger>How do I write expressions?</AccordionTrigger>
        <AccordionContent>
          Use a period for decimal numbers, commas between function arguments, and radians for trigonometry.
          Try <code>avg(12,18,24)</code> or <code>sin(pi / 2)</code>. Open the <strong>f</strong> panel to see available functions.
        </AccordionContent>
      </AccordionItem>
      <AccordionItem value="languages">
        <AccordionTrigger>Which languages are available?</AccordionTrigger>
        <AccordionContent>
          EvaBar follows your system language by default. Choose English, Simplified Chinese, Traditional Chinese,
          Japanese, Korean, German, French, Spanish, Brazilian Portuguese, or Italian in Preferences.
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  );
}
