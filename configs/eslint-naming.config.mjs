import tseslint from "typescript-eslint";

const privateMember = {
  format: ["camelCase"],
  leadingUnderscore: "forbid",
  trailingUnderscore: "require",
};

const namingConvention = (functionFormats) => [
  "error",
  { selector: "default", format: ["camelCase"] },
  { selector: "variable", format: ["camelCase", "UPPER_CASE"] },
  { selector: "function", format: functionFormats },
  { selector: "parameter", format: ["camelCase"], leadingUnderscore: "allow" },
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
      "@typescript-eslint/naming-convention": namingConvention(["camelCase"]),
    },
  },
  {
    files: ["**/*.tsx"],
    rules: {
      "@typescript-eslint/naming-convention": namingConvention(["camelCase", "PascalCase"]),
    },
  },
];
