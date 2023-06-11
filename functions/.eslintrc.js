module.exports = {
  root: true,
  env: {
    es6: true,
    node: true
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended"
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module"
  },
  ignorePatterns: [
    "/lib/**/*" // Ignore built files.
  ],
  plugins: ["@typescript-eslint", "import"],
  rules: {
    "quote-props": ["error", "as-needed"],
    quotes: ["error", "single"],
    "import/no-unresolved": 0,
    indent: [
      "error",
      2,
      {
        CallExpression: {
          arguments: "first"
        }
      }
    ],
    "function-call-argument-newline": ["error", "multiline"],
    semi: ["error", "never"],
    // eslint-disable-next-line object-curly-spacing
    "max-len": ["error", {code: 120}],
    "@typescript-eslint/no-unused-vars": [
      "warn", // or "error"
      {
        argsIgnorePattern: "^_",
        varsIgnorePattern: "^_",
        caughtErrorsIgnorePattern: "^_"
      }
    ]
  }
};
