// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A single-line JavaScript preamble prepended to dart2js-compiled Node.js test
/// files.
///
/// Must not contain newlines so that source map line numbers emitted by dart2js
/// remain aligned with the compiled output.
const nodePreamble =
    // Create a module-scoped `self` inheriting from `globalThis` so dart2js
    // globals (such as `location` and CommonJS locals) do not pollute
    // `globalThis`.
    'const self=Object.create(globalThis);'
    // Forward `globalThis.crypto` with the right `this` receiver; on Node 19+,
    // `globalThis.crypto` is a WebIDL accessor that throws `ERR_INVALID_THIS`
    // when accessed via an object inheriting from `globalThis` (breaking
    // `Random.secure()`).
    'if("crypto"in globalThis)'
    'Object.defineProperty(self,"crypto",{'
    'get(){return globalThis.crypto;},'
    'configurable:true,enumerable:true'
    '});'
    // Expose CommonJS module-wrapper locals on `self` so Dart JS interop
    // bindings (e.g. `@JS() external ... require(...)`) can access them.
    'if(typeof require!=="undefined")self.require=require;'
    'if(typeof exports!=="undefined")self.exports=exports;'
    'if(typeof __dirname!=="undefined")self.__dirname=__dirname;'
    'if(typeof __filename!=="undefined")self.__filename=__filename;'
    // Provide `self.location.href` for `Uri.base`, ensuring a trailing slash
    // without doubling it when `process.cwd()` is the filesystem root.
    'self.location={get href(){'
    'const h=require("node:url").pathToFileURL(process.cwd()).href;'
    'return h.endsWith("/")?h:h+"/";'
    '}};';
