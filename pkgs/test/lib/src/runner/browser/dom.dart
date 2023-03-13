// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_util' as js_util;

import 'package:js/js.dart';

// Conversion functions to help with the migration.
extension ObjectToJSAnyExtension on Object? {
  JSAny? get toJSAnyShallow {
    if (const bool.fromEnvironment('dart.library.html')) {
      // Cast is necessary on Wasm backends and in the future on JS backends as
      // well.
      // ignore: unnecessary_cast
      return this as JSAny?;
    } else {
      return toJSAnyDeep;
    }
  }

  JSAny? get toJSAnyDeep => js_util.jsify(this) as JSAny?;
}

extension JSAnyToObjectExtension on JSAny? {
  Object? get toObjectShallow {
    if (const bool.fromEnvironment('dart.library.html')) {
      return this;
    } else {
      return toObjectDeep;
    }
  }

  Object? get toObjectDeep => js_util.dartify(this);
}


@JS()
@staticInterop
class Window extends EventTarget {}

extension WindowExtension on Window {
  external Location get location;

  @JS('getComputedStyle')
  external CSSStyleDeclaration? _getComputedStyle1(Element elt);
  @JS('getComputedStyle')
  external CSSStyleDeclaration? _getComputedStyle2(Element elt, JSString pesudoElt);
  CSSStyleDeclaration? getComputedStyle(Element elt, [String? pseudoElt]) {
    if (pseudoElt == null) {
      return _getComputedStyle1(elt);
    } else {
      return _getComputedStyle2(elt, pseudoElt.toJS);
    }
  }
  external Navigator get navigator;

  @JS('postMessage')
  external JSVoid _postMessage1(JSAny message, JSString targetOrigin);
  @JS('postMessage')
  external JSVoid _postMessage2(JSAny message, JSString targetOrigin, JSAny
      messagePorts);
  void postMessage(Object message, String targetOrigin,
          [List<MessagePort>? messagePorts]) {
    if (messagePorts == null) {
      _postMessage1(message.toJSAnyDeep!, targetOrigin.toJS);
    } else {
      _postMessage2(message.toJSAnyDeep!, targetOrigin.toJS,
          messagePorts.toJSAnyDeep!);
    }
  }
}

@JS('window')
external Window get window;

@JS()
@staticInterop
class Document extends Node {}

extension DocumentExtension on Document {
  @JS('querySelector')
  external Element? _querySelector(JSString selectors);
  Element? querySelector(String selectors) =>
      _querySelector(selectors.toJS);

  @JS('createElement')
  external Element _createElement1(JSString name);
  @JS('createElement')
  external Element _createElement2(JSString name, JSAny options);
  Element createElement(String name, [Object? options]) {
    if (options == null) {
      return _createElement1(name.toJS);
    } else {
      return _createElement2(name.toJS, options.toJSAnyShallow!);
    }
  }
}

@JS()
@staticInterop
class HTMLDocument extends Document {}

extension HTMLDocumentExtension on HTMLDocument {
  external HTMLBodyElement? get body;

  @JS('title')
  external JSString? get _title;
  String? get title => _title?.toDart;
}

@JS('document')
external HTMLDocument get document;

@JS()
@staticInterop
class Navigator {}

extension NavigatorExtension on Navigator {
  @JS('userAgent')
  external JSString get _userAgent;
  String get userAgent => _userAgent.toDart;
}

@JS()
@staticInterop
class Element extends Node {}

extension DomElementExtension on Element {
  external DomTokenList get classList;
}

@JS()
@staticInterop
class HTMLElement extends Element {}

@JS()
@staticInterop
class HTMLBodyElement extends HTMLElement {}

@JS()
@staticInterop
class Node extends EventTarget {}

extension NodeExtension on Node {
  external Node appendChild(Node node);
  void remove() {
    if (parentNode != null) {
      final Node parent = parentNode!;
      parent.removeChild(this);
    }
  }

  external Node removeChild(Node child);
  external Node? get parentNode;
}

@JS()
@staticInterop
class EventTarget {}

extension EventTargetExtension on EventTarget {
  @JS('addEventListener')
  external JSVoid _addEventListener1(JSString type, JSFunction? listener);
  @JS('addEventListener')
  external JSVoid _addEventListener2(JSString type, JSFunction? listener,
      JSBoolean useCapture);
  void addEventListener(String type, JSFunction? listener,
      [bool? useCapture]) {
    if (listener != null) {
      if (useCapture == null) {
        _addEventListener1(type.toJS, listener);
      } else {
        _addEventListener2(type.toJS, listener, useCapture.toJS);
      }
    }
  }

  @JS('removeEventListener')
  external JSVoid _removeEventListener1(JSString type, JSFunction? listener);
  @JS('removeEventListener')
  external JSVoid _removeEventListener2(JSString type, JSFunction? listener,
      JSBoolean useCapture);
  void removeEventListener(String type, JSFunction? listener,
      [bool? useCapture]) {
    if (listener != null) {
      if (useCapture == null) {
        _removeEventListener1(type.toJS, listener);
      } else {
        _removeEventListener2(type.toJS, listener, useCapture.toJS);
      }
    }
  }
}

typedef EventListener = void Function(Event event);
JSFunction createEventListener(EventListener listener) => listener.toJS;

@JS()
@staticInterop
class Event {}

extension EventExtension on Event {
  external JSVoid stopPropagation();
}

@JS()
@staticInterop
class MessageEvent extends Event {}

extension MessageEventExtension on MessageEvent {
  @JS('data')
  external JSAny? get _data;
  dynamic get data => _data.toObjectDeep;

  @JS('origin')
  external JSString get _origin;
  String get origin => _origin.toDart;

  @JS('ports')
  external JSArray get _ports;
  List<MessagePort> get ports => _ports.toDart.cast<MessagePort>();
}

@JS()
@staticInterop
class Location {}

extension LocationExtension on Location {
  @JS('href')
  external JSString get _href;
  String get href => _href.toDart;

  @JS('origin')
  external JSString get _origin;
  String get origin => _origin.toDart;
}

@JS()
@staticInterop
class MessagePort extends EventTarget {}

extension MessagePortExtension on MessagePort {
  @JS('postMessage')
  external JSVoid _postMessage1();
  @JS('postMessage')
  external JSVoid _postMessage2(JSAny? message);
  void postMessage(Object? message) {
    if(message == null) {
      _postMessage1();
    } else {
      _postMessage2(message.toJSAnyDeep);
    }
  }
  external JSVoid start();
}

@JS()
@staticInterop
class CSSStyleDeclaration {}

@JS()
@staticInterop
class HTMLScriptElement extends HTMLElement {}

extension HTMLScriptElementExtension on HTMLScriptElement {
  @JS('src')
  external set _src(JSString value);
  set src(String value) => _src = value.toJS;
}

HTMLScriptElement createHTMLScriptElement() =>
    document.createElement('script') as HTMLScriptElement;

@JS()
@staticInterop
class DomTokenList {}

extension DomTokenListExtension on DomTokenList {
  @JS('add')
  external JSVoid _add(JSString value);
  void add(String value) => _add(value.toJS);

  @JS('remove')
  external JSVoid _remove(JSString value);
  void remove(String value) => _remove(value.toJS);

  @JS('contains')
  external JSBoolean _contains(JSString token);
  bool contains(String token) => _contains(token.toJS).toDart;
}

@JS()
@staticInterop
class HTMLIFrameElement extends HTMLElement {}

extension HTMLIFrameElementExtension on HTMLIFrameElement {
  @JS('src')
  external JSString? get _src;
  String? get src => _src?.toDart;

  @JS('src')
  external set _src(JSString? value);
  set src(String? value) => _src = value?.toJS;

  external Window get contentWindow;
}

HTMLIFrameElement createHTMLIFrameElement() =>
    document.createElement('iframe') as HTMLIFrameElement;

@JS('WebSocket')
@staticInterop
class WebSocket extends EventTarget {
  external factory WebSocket(JSString url);
}

extension WebSocketExtension on WebSocket {
  @JS('send')
  external JSVoid _send(JSAny? data);
  void send(Object? data) => _send(data.toJSAnyShallow);
}

WebSocket createWebSocket(String url) => WebSocket(url.toJS);

@JS('MessageChannel')
@staticInterop
class MessageChannel {
  external factory MessageChannel();
}

extension MessageChannelExtension on MessageChannel {
  external MessagePort get port1;
  external MessagePort get port2;
}

MessageChannel createMessageChannel() => MessageChannel();

class Subscription {
  final JSString type;
  final EventTarget target;
  final JSFunction listener;

  Subscription(this.target, String typeStr, EventListener dartListener) :
    type = typeStr.toJS, listener = dartListener.toJS {
    target._addEventListener1(type, listener);
  }

  void cancel() => target._removeEventListener1(type, listener);
}
