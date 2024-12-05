// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Vendored version of node_preamble.

final _minified =
    r'''var dartNodeIsActuallyNode="undefined"!=typeof process&&(process.versions||{}).hasOwnProperty("node"),self=dartNodeIsActuallyNode?Object.create(globalThis):globalThis;if(self.scheduleImmediate="undefined"!=typeof setImmediate?function(e){setImmediate(e)}:function(e){setTimeout(e,0)},"undefined"!=typeof require)self.require=require;if("undefined"!=typeof exports)self.exports=exports;if("undefined"!=typeof process)self.process=process;if("undefined"!=typeof __dirname)self.__dirname=__dirname;if("undefined"!=typeof __filename)self.__filename=__filename;if("undefined"!=typeof Buffer)self.Buffer=Buffer;if(dartNodeIsActuallyNode){var url=("undefined"!=typeof __webpack_require__?__non_webpack_require__:require)("url");Object.defineProperty(self,"location",{value:{get href(){if(url.pathToFileURL)return url.pathToFileURL(process.cwd()).href+"/";else return"file://"+function(){var e=process.cwd();if("win32"!=process.platform)return e;else return"/"+e.replace(/\\/g,"/")}()+"/"}}}),function(){function e(){try{throw new Error}catch(n){var e=n.stack,r=new RegExp("^ *at [^(]*\\((.*):[0-9]*:[0-9]*\\)$","mg"),f=null;do{var t=r.exec(e);if(null!=t)f=t}while(null!=t);return f[1]}}var r=null;Object.defineProperty(self,"document",{value:{get currentScript(){if(null==r)r={src:e()};return r}}})}(),self.dartDeferredLibraryLoader=function(e,r,f){try{load(e),r()}catch(e){f(e)}}}''';

final _normal = r'''
var dartNodeIsActuallyNode = typeof process !== "undefined" && (process.versions || {}).hasOwnProperty('node');

// make sure to keep this as 'var'
// we don't want block scoping
var self = dartNodeIsActuallyNode ? Object.create(globalThis) : globalThis;

self.scheduleImmediate = typeof setImmediate !== "undefined"
    ? function (cb) {
        setImmediate(cb);
      }
    : function(cb) {
        setTimeout(cb, 0);
      };

// CommonJS globals.
if (typeof require !== "undefined") {
  self.require = require;
}
if (typeof exports !== "undefined") {
  self.exports = exports;
}

// Node.js specific exports, check to see if they exist & or polyfilled

if (typeof process !== "undefined") {
  self.process = process;
}

if (typeof __dirname !== "undefined") {
  self.__dirname = __dirname;
}

if (typeof __filename !== "undefined") {
  self.__filename = __filename;
}

if (typeof Buffer !== "undefined") {
  self.Buffer = Buffer;
}

// if we're running in a browser, Dart supports most of this out of box
// make sure we only run these in Node.js environment

if (dartNodeIsActuallyNode) {
  // This line is to:
  // 1) Prevent Webpack from bundling.
  // 2) In Webpack on Node.js, make sure we're using the native Node.js require, which is available via __non_webpack_require__
  // https://github.com/mbullington/node_preamble.dart/issues/18#issuecomment-527305561
  var url = ("undefined" !== typeof __webpack_require__ ? __non_webpack_require__ : require)("url");

  // Setting `self.location=` in Electron throws a `TypeError`, so we define it
  // as a property instead to be safe.
  Object.defineProperty(self, "location", {
    value: {
      get href() {
        if (url.pathToFileURL) {
          return url.pathToFileURL(process.cwd()).href + "/";
        } else {
          // This isn't really a correct transformation, but it's the best we have
          // for versions of Node <10.12.0 which introduced `url.pathToFileURL()`.
          // For example, it will fail for paths that contain characters that need
          // to be escaped in URLs.
          return "file://" + (function() {
            var cwd = process.cwd();
            if (process.platform != "win32") return cwd;
            return "/" + cwd.replace(/\\/g, "/");
          })() + "/"
        }
      }
    }
  });

  (function() {
    function computeCurrentScript() {
      try {
        throw new Error();
      } catch(e) {
        var stack = e.stack;
        var re = new RegExp("^ *at [^(]*\\((.*):[0-9]*:[0-9]*\\)$", "mg");
        var lastMatch = null;
        do {
          var match = re.exec(stack);
          if (match != null) lastMatch = match;
        } while (match != null);
        return lastMatch[1];
      }
    }

    // Setting `self.document=` isn't known to throw an error anywhere like
    // `self.location=` does on Electron, but it's better to be future-proof
    // just in case..
    var cachedCurrentScript = null;
    Object.defineProperty(self, "document", {
      value: {
        get currentScript() {
          if (cachedCurrentScript == null) {
            cachedCurrentScript = {src: computeCurrentScript()};
          }
          return cachedCurrentScript;
        }
      }
    });
  })();

  self.dartDeferredLibraryLoader = function(uri, successCallback, errorCallback) {
    try {
     load(uri);
      successCallback();
    } catch (error) {
      errorCallback(error);
    }
  };
}
''';

/// Returns the text of the preamble.
///
/// If [minified] is true, returns the minified version rather than the
/// human-readable version.
String getPreamble(
        {bool minified = false, List<String> additionalGlobals = const []}) =>
    (minified ? _minified : _normal) +
    (additionalGlobals.map((global) => 'self.$global=$global;').join());
