locale = {
  name = "en",
  charset = "cp1252",
  languageName = "English",

  formatNumbers = true,
  decimalSeperator = '.',
  thousandsSeperator = ',',

  -- A missing key already falls back to the English source, so this table only ever holds
  -- keys whose source string is not what should be rendered.
  translation = {
    ["%d remaining (singular)"] = "%d remaining",
  }
}

modules.client_locales.installLocale(locale)
