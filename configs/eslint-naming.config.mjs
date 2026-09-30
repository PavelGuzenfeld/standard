import tseslint from "typescript-eslint";

const privateMember = {
  format: ["snake_case"],
  leadingUnderscore: "forbid",
  trailingUnderscore: "require",
};

const namingConvention = (functionFormats) => [
  "error",
  { selector: "default", format: ["snake_case"] },
  { selector: "variable", format: ["snake_case", "UPPER_CASE"] },
  { selector: "function", format: functionFormats },
  { selector: "parameter", format: ["snake_case"], leadingUnderscore: "allow" },
  { selector: "typeLike", format: ["PascalCase"] },
  {
    selector: "interface",
    format: ["PascalCase"],
    custom: { regex: "^I[A-Z]", match: false },
  },
  { selector: "enumMember", format: ["PascalCase"] },
  { selector: "objectLiteralProperty", format: null },
  { selector: "typeProperty", format: null },
  { selector: "memberLike", modifiers: ["private"], ...privateMember },
  { selector: "memberLike", modifiers: ["#private"], ...privateMember },
  { selector: "parameterProperty", modifiers: ["private"], ...privateMember },
];

export default [
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: { parser: tseslint.parser },
    plugins: { "@typescript-eslint": tseslint.plugin },
    rules: {
      "@typescript-eslint/naming-convention": namingConvention(["snake_case"]),
    },
  },
  {
    files: ["**/*.tsx"],
    rules: {
      "@typescript-eslint/naming-convention": namingConvention(["snake_case", "PascalCase"]),
    },
  },
];
