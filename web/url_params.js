// URL parameter handling is now done directly in Nim code
// This file is kept for backward compatibility but is no longer used
//
// URL parameters are parsed in nimini/stdlib/params.nim using:
//   parseUrlParams() - parses window.location.search in WASM
//
// Parameters are accessed via:
//   getParam("name") - get parameter value
//   hasParam("name") - check if parameter exists
//   getParamInt("name", default) - get parameter as integer

// No JavaScript bridge needed anymore!
