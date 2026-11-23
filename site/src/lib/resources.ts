export interface ResourcePage {
  path: string;
  title: string;
  heading: string;
  description: string;
}

export const resources = {
  calcbar: {
    path: "/compare/calcbar-1-6/",
    title: "CalcBar 1.6 Alternative for Mac — Eva|Bar",
    heading: "CalcBar 1.6 vs. Eva|Bar",
    description: "CalcBar 1.6 needs Rosetta on Apple silicon and will stop working on macOS 28. Compare it with Eva|Bar, a native Mac menu bar calculator.",
  },
  spotlight: {
    path: "/compare/spotlight-calculator/",
    title: "Mac Spotlight Calculator vs. Eva|Bar",
    heading: "Mac Spotlight Calculator vs. Eva|Bar",
    description: "See how Spotlight handles quick calculations and conversions, and how Eva|Bar keeps a floating calculator visible while you work.",
  },
  floating: {
    path: "/guides/floating-calculator/",
    title: "How to Use a Floating Calculator on Mac — Eva|Bar",
    heading: "How to use a floating calculator on Mac",
    description: "Open Eva|Bar with Control–Shift–Space, pin the floating calculator above other Mac windows, and press Return to copy the result.",
  },
  expressions: {
    path: "/guides/calculator-expressions/",
    title: "Mac Calculator Expressions and Functions — Eva|Bar",
    heading: "Calculator expressions and functions on Mac",
    description: "Try Eva|Bar expressions for discounts, averages, remainders, logarithms, and trigonometry. Learn how to format the results you copy.",
  },
  features: {
    path: "/features/",
    title: "Eva|Bar Features — Menu Bar Icons, Shortcuts and More",
    heading: "Eva|Bar features and preferences",
    description: "Preview Eva|Bar’s 10 menu bar icons. Learn to change or hide the icon and set shortcuts, number formatting, launch at login, and language.",
  },
} satisfies Record<string, ResourcePage>;

export const resourcePages = Object.values(resources);
