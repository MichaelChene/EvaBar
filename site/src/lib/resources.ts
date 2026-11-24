export interface ResourcePage {
  path: string;
  title: string;
  heading: string;
  description: string;
}

export const resources = {
  calcbar: {
    path: "/compare/calcbar-1-6/",
    title: "CalcBar 1.6 Alternative for Mac — EvaBar",
    heading: "CalcBar 1.6 vs. EvaBar",
    description: "Compare CalcBar 1.6 and EvaBar on price, macOS compatibility, large-number precision, long results, interface languages, and Liquid Glass.",
  },
  spotlight: {
    path: "/compare/spotlight-calculator/",
    title: "Mac Spotlight Calculator vs. EvaBar",
    heading: "Mac Spotlight Calculator vs. EvaBar",
    description: "See how Spotlight handles quick calculations and conversions, and how EvaBar keeps a floating calculator visible while you work.",
  },
  floating: {
    path: "/guides/floating-calculator/",
    title: "How to Use a Floating Calculator on Mac — EvaBar",
    heading: "How to use a floating calculator on Mac",
    description: "Open EvaBar with Control–Shift–Space, pin the floating calculator above other Mac windows, and press Return to copy the result.",
  },
  expressions: {
    path: "/guides/calculator-expressions/",
    title: "Mac Calculator Expressions and Functions — EvaBar",
    heading: "Calculator expressions and functions on Mac",
    description: "Try EvaBar expressions for discounts, averages, remainders, logarithms, and trigonometry. Learn how to format the results you copy.",
  },
  features: {
    path: "/features/",
    title: "EvaBar Features — Menu Bar Icons, Shortcuts and More",
    heading: "EvaBar features and preferences",
    description: "Learn how to switch Liquid Glass on or off, change or hide the menu bar icon, and set keyboard shortcuts and number formatting in EvaBar.",
  },
} satisfies Record<string, ResourcePage>;

export const resourcePages = Object.values(resources);
