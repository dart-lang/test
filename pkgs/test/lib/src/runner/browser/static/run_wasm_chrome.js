// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(joshualitt): Investigate making this a module. Currently, Dart2Wasm is
// broken in D8 with modules because of an issue with async. This may or may not
// affect chrome.
(async () => {
  // Fetch and compile Wasm binary.
  let data = document.getElementById('WasmBootstrapInfo').dataset;

  // Instantiate the Dart module, importing from the global scope.
  let dart2wasmJsRuntime = await import('./' + data.jsruntimeurl);
  let compiledModule = await dart2wasmJsRuntime.compileStreaming(fetch(data.wasmurl));
  let instantiatedModule = await compiledModule.instantiate()

  // Call `main`. If tasks are placed into the event loop (by scheduling tasks
  // explicitly or awaiting Futures), these will automatically keep the script
  // alive even after `main` returns.
  await instantiatedModule.invokeMain();
})();
