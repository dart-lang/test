// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(joshualitt): Investigate making this a module. Currently, Dart2Wasm is
// broken in D8 with modules because of an issue with async. This may or may not
// affect chrome.
(async () => {
  // Fetch and compile Wasm binary.
  let wasmUrl, jsRuntimeUrl;
  let dataElement = document.getElementById("WasmBootstrapInfo");
  if (dataElement) {
    wasmUrl = dataElement.dataset.wasmurl;
    jsRuntimeUrl = "./" + dataElement.dataset.jsruntimeurl;
  } else {
    // Infer from current script
    let scriptSrc = document.currentScript.src;
    wasmUrl = scriptSrc.replace(/\.js$/, '.wasm');
    jsRuntimeUrl = scriptSrc.replace(/\.js$/, '.mjs');
  }

  // Instantiate the Dart module, importing from the global scope.
  let dart2wasmJsRuntime = await import(jsRuntimeUrl);

  // dart2wasm versions starting with 3.6.0-212.0.dev return a new type that
  // comes with instantiation and invoke methods. Since the min SDK is 3.7,
  // we only need to support this version.
  let compiledModule = await dart2wasmJsRuntime.compileStreaming(
    fetch(wasmUrl),
  );
  let instantiatedModule = await compiledModule.instantiate();
  instantiatedModule.invokeMain();
})();
