// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(joshualitt): Investigate making this a module. Currently, Dart2Wasm is
// broken in D8 with modules because of an issue with async. This may or may not
// affect chrome.
(async () => {
  // Fetch and compile Wasm binary.
  let data = document.getElementById("WasmBootstrapInfo").dataset;

  // Instantiate the Dart module, importing from the global scope.
  let dart2wasmJsRuntime = await import("./" + data.jsruntimeurl);

  // Support three versions of dart2wasm:
  //
  // (1) Versions before 3.6.0-167.0.dev require the user to compile using the
  // browser's `WebAssembly` API, the compiled module needs to be instantiated
  // using the JS runtime.
  //
  // (2) Versions starting with 3.6.0-167.0.dev added helpers for compiling and
  // instantiating.
  //
  // (3) Versions starting with 3.6.0-212.0.dev made compilation functions
  // return a new type that comes with instantiation and invoke methods.

  if (dart2wasmJsRuntime.compileStreaming !== undefined) {
    // Version (2) or (3).
    let compiledModule = await dart2wasmJsRuntime.compileStreaming(
      fetch(data.wasmurl),
    );
    if (compiledModule.instantiate !== undefined) {
      // Version (3).
      let instantiatedModule = await compiledModule.instantiate();
      instantiatedModule.invokeMain();
    } else {
      // Version (2).
      let dartInstance = await dart2wasmJsRuntime.instantiate(compiledModule, {});
      await dart2wasmJsRuntime.invoke(dartInstance);
    }
  } else {
    // Version (1).
    let modulePromise = WebAssembly.compileStreaming(fetch(data.wasmurl));
    let dartInstance = await dart2wasmJsRuntime.instantiate(modulePromise, {});
    await dart2wasmJsRuntime.invoke(dartInstance);
  }
})();
