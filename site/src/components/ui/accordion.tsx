import * as Primitive from "@radix-ui/react-accordion";
import { ChevronDown } from "lucide-react";
import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

const Accordion = Primitive.Root;

function AccordionItem({ className, ...props }: ComponentProps<typeof Primitive.Item>) {
  return <Primitive.Item className={cn("border-b border-border", className)} {...props} />;
}

function AccordionTrigger({ className, children, ...props }: ComponentProps<typeof Primitive.Trigger>) {
  return (
    <Primitive.Header className="flex">
      <Primitive.Trigger
        className={cn("flex w-full items-center justify-between gap-4 rounded-sm py-5 text-left font-medium outline-none hover:text-primary focus-visible:ring-2 focus-visible:ring-ring [&[data-state=open]>svg]:rotate-180", className)}
        {...props}
      >
        {children}
        <ChevronDown className="size-4 shrink-0 text-muted-foreground transition-transform motion-reduce:transition-none" aria-hidden="true" />
      </Primitive.Trigger>
    </Primitive.Header>
  );
}

function AccordionContent({ className, children, ...props }: ComponentProps<typeof Primitive.Content>) {
  return (
    <Primitive.Content {...props}>
      <div className={cn("max-w-prose pb-5 leading-7 text-muted-foreground", className)}>{children}</div>
    </Primitive.Content>
  );
}

export { Accordion, AccordionContent, AccordionItem, AccordionTrigger };
