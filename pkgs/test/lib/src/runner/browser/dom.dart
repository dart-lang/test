// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

extension type Window(EventTarget _) implements EventTarget {
  @pragma('dart2js:as:trust')
  Window get parent => getProperty('parent'.toJS) as Window;

  external Location get location;

  Console get console => getProperty('console'.toJS) as Console;

  CSSStyleDeclaration? getComputedStyle(Element elt, [String? pseudoElt]) =>
      callMethodVarArgs('getComputedStyle'.toJS, <JSAny?>[
        elt,
        if (pseudoElt != null) pseudoElt.toJS
      ]) as CSSStyleDeclaration?;

  external Navigator get navigator;

  void postMessage(Object message, String targetOrigin,
          [List<MessagePort>? messagePorts]) =>
      callMethodVarArgs('postMessage'.toJS, <JSAny?>[
        message.jsify(),
        targetOrigin.toJS,
        if (messagePorts != null) messagePorts.toJS
      ]);
}

@JS('window')
external Window get window;

extension type Console(JSObject _) implements JSObject {
  external void log(JSAny? object);
  external void warn(JSAny? object);
}

extension type Document(Node _) implements Node {
  external Element? querySelector(String selectors);

  Element createElement(String name, [Object? options]) => callMethodVarArgs(
      'createElement'.toJS,
      <JSAny?>[name.toJS, if (options != null) options.jsify()]) as Element;
}

extension type HTMLDocument(Document _) implements Document {
  external HTMLBodyElement? get body;
  external String? get title;
}

@JS('document')
external HTMLDocument get document;

extension type Navigator(JSObject _) implements JSObject {
  external String get userAgent;
}

extension type Element(Node _) implements Node {
  external DomTokenList get classList;
}

extension type HTMLElement(Element _) implements Element {}

extension type HTMLBodyElement(HTMLElement _) implements HTMLElement {}

extension type Node(EventTarget _) implements EventTarget {
  external Node appendChild(Node node);
  void remove() {
    if (parentNode != null) {
      final parent = parentNode!;
      parent.removeChild(this);
    }
  }

  external Node removeChild(Node child);
  external Node? get parentNode;
}

extension type EventTarget(JSObject _) implements JSObject {
  void addEventListener(String type, EventListener? listener,
      [bool? useCapture]) {
    if (listener != null) {
      callMethodVarArgs('addEventListener'.toJS, <JSAny?>[
        type.toJS,
        listener.toJS,
        if (useCapture != null) useCapture.toJS
      ]);
    }
  }

  void removeEventListener(String type, EventListener? listener,
      [bool? useCapture]) {
    if (listener != null) {
      callMethodVarArgs('removeEventListener'.toJS, <JSAny?>[
        type.toJS,
        listener.toJS,
        if (useCapture != null) useCapture.toJS
      ]);
    }
  }
}

typedef EventListener = void Function(Event event);

extension type Event(JSObject _) implements JSObject {
  external void stopPropagation();
}

extension type MessageEvent(Event _) implements Event {
  dynamic get data => getProperty('data'.toJS).dartify();

  external String get origin;

  List<MessagePort> get ports =>
      getProperty<JSArray>('ports'.toJS).toDart.cast<MessagePort>();

  /// The source may be a `WindowProxy`, a `MessagePort`, or a `ServiceWorker`.
  ///
  /// When a message is sent from an iframe through `window.parent.postMessage`
  /// the source will be a `WindowProxy` which has the same methods as [Window].
  @pragma('dart2js:as:trust')
  MessageEventSource get source =>
      getProperty('source'.toJS) as MessageEventSource;
}

extension type MessageEventSource(JSObject _) implements JSObject {
  @pragma('dart2js:as:trust')
  MessageEventSourceLocation? get location =>
      getProperty('location'.toJS) as MessageEventSourceLocation;
}

extension type MessageEventSourceLocation(JSObject _) implements JSObject {
  external String? get href;
}

extension type Location(JSObject _) implements JSObject {
  external String get href;
  external String get origin;
}

extension type MessagePort(EventTarget _) implements EventTarget {
  void postMessage(Object? message) => callMethodVarArgs(
      'postMessage'.toJS, <JSAny?>[if (message != null) message.jsify()]);

  external void start();
}

extension type CSSStyleDeclaration(JSObject _) implements JSObject {}

extension type HTMLScriptElement(HTMLElement _) implements HTMLElement {
  external set src(String value);
}

HTMLScriptElement createHTMLScriptElement() =>
    document.createElement('script') as HTMLScriptElement;

extension type DomTokenList(JSObject _) implements JSObject {
  external void add(String value);
  external void remove(String value);
  external bool contains(String token);
}

extension type HTMLIFrameElement(HTMLElement _) implements HTMLElement {
  external String? get src;
  external set src(String? value);
  external Window get contentWindow;
}

HTMLIFrameElement createHTMLIFrameElement() =>
    document.createElement('iframe') as HTMLIFrameElement;

extension type WebSocket(EventTarget _) implements EventTarget {
  external void send(JSAny? data);
}

WebSocket createWebSocket(String url) =>
    _callConstructor('WebSocket', <JSAny?>[url.toJS])! as WebSocket;

extension type MessageChannel(JSObject _) implements JSObject {
  external MessagePort get port1;
  external MessagePort get port2;
}

MessageChannel createMessageChannel() =>
    _callConstructor('MessageChannel', <JSAny?>[])! as MessageChannel;

Object? _callConstructor(String constructorName, List<JSAny?> args) {
  final constructor = window.getProperty(constructorName.toJS) as JSFunction?;
  if (constructor == null) {
    return null;
  }

  return constructor.callAsConstructorVarArgs(args);
}

class Subscription {
  final String type;
  final EventTarget target;
  final EventListener listener;

  Subscription(this.target, this.type, this.listener) {
    target.addEventListener(type, listener);
  }

  void cancel() => target.removeEventListener(type, listener);
}
