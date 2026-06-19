// Canonical Go foreign for module Runtime. psgo has no user-foreign copy step
// yet, so today this is applied by hand (see Makefile run-go); once psgo gains
// an ffi-go/ analog of purejl's copyUserForeigns, this is picked up directly.
package main

var Runtime_runtimeName any = "Go (native binary)"
