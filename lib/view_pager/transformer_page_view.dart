import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:page_transition_cube/view_pager/transformers.dart';

const int kMaxValue = 2000000000;
const int kMiddleValue = 1000000000;

const int kDefaultTransactionDuration = 300;

class IndexController extends ChangeNotifier {
  static const int NEXT = 1;
  static const int PREVIOUS = -1;
  static const int MOVE = 0;

  Completer _completer;

  int index;
  bool animation;
  int event;

  Future move(int index, {bool animation: true}) {
    this.animation = animation ?? true;
    this.index = index;
    this.event = MOVE;
    _completer = Completer();
    notifyListeners();
    return _completer.future;
  }

  Future next({bool animation: true}) {
    this.event = NEXT;
    this.animation = animation ?? true;
    _completer = Completer();
    notifyListeners();
    return _completer.future;
  }

  Future previous({bool animation: true}) {
    this.event = PREVIOUS;
    this.animation = animation ?? true;
    _completer = Completer();
    notifyListeners();
    return _completer.future;
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class TransformInfo {
  final double width;
  final double height;
  final double position;
  final int index;
  final int activeIndex;
  final int fromIndex;
  final bool forward;
  final bool done;
  final double viewportFraction;
  final Axis scrollDirection;

  TransformInfo(
      {this.index,
      this.position,
      this.width,
      this.height,
      this.activeIndex,
      this.fromIndex,
      this.forward,
      this.done,
      this.viewportFraction,
      this.scrollDirection});
}

abstract class PageTransformer {
  final bool reverse;

  PageTransformer({this.reverse: false});

  Widget transform(Widget child, TransformInfo info);
}

class TransformerPageController extends PageController {
  final bool loop;
  final int itemCount;
  final bool reverse;

  TransformerPageController({
    int initialPage = 0,
    bool keepPage = true,
    double viewportFraction = 1.0,
    this.loop: false,
    this.itemCount,
    this.reverse: false,
  }) : super(
          initialPage: TransformerPageController._getRealIndexFromRenderIndex(initialPage ?? 0, loop, itemCount, reverse),
          keepPage: keepPage,
          viewportFraction: viewportFraction,
        );

  int getRenderIndexFromRealIndex(num index) => _getRenderIndexFromRealIndex(index, loop, itemCount, reverse);

  int getRealItemCount() {
    if (itemCount == 0) return 0;

    return loop ? itemCount + kMaxValue : itemCount;
  }

  static _getRenderIndexFromRealIndex(num index, bool loop, int itemCount, bool reverse) {
    if (itemCount == 0) return 0;

    int renderIndex;
    if (loop) {
      renderIndex = index - kMiddleValue;
      renderIndex = renderIndex % itemCount;
      if (renderIndex < 0) renderIndex += itemCount;
    } else {
      renderIndex = index;
    }
    if (reverse) renderIndex = itemCount - renderIndex - 1;

    return renderIndex;
  }

  double get realPage {
    double page;
    if (position.maxScrollExtent == null || position.minScrollExtent == null) {
      page = 0.0;
    } else {
      page = super.page;
    }

    return page;
  }

  static _getRenderPageFromRealPage(double page, bool loop, int itemCount, bool reverse) {
    double renderPage;
    if (loop) {
      renderPage = page - kMiddleValue;
      renderPage = renderPage % itemCount;
      if (renderPage < 0) {
        renderPage += itemCount;
      }
    } else {
      renderPage = page;
    }
    if (reverse) {
      renderPage = itemCount - renderPage - 1;
    }
    return renderPage;
  }

  double get page => loop ? _getRenderPageFromRealPage(realPage, loop, itemCount, reverse) : realPage;

  int getRealIndexFromRenderIndex(num index) => _getRealIndexFromRenderIndex(index, loop, itemCount, reverse);

  static int _getRealIndexFromRenderIndex(num index, bool loop, int itemCount, bool reverse) {
    int result = reverse ? (itemCount - index - 1) : index;
    if (loop) {
      result += kMiddleValue;
    }
    return result;
  }
}

class TransformerPageView extends StatefulWidget {
  final PageTransformer transformer;
  final Axis scrollDirection;
  final ScrollPhysics physics;
  final bool pageSnapping;
  final ValueChanged<int> onPageChanged;
  final IndexedWidgetBuilder itemBuilder;
  final IndexController controller;
  final Duration duration;
  final Curve curve;
  final TransformerPageController pageController;
  final bool loop;
  final int itemCount;
  final double viewportFraction;
  final int index;

  TransformerPageView({
    Key key,
    this.index,
    Duration duration,
    this.curve: Curves.ease,
    this.viewportFraction: 1.0,
    this.loop: false,
    this.scrollDirection = Axis.horizontal,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    this.controller,
    this.transformer,
    this.itemBuilder,
    this.pageController,
    @required this.itemCount,
  })  : assert(itemCount != null),
        assert(itemCount == 0 || itemBuilder != null || transformer != null),
        this.duration = duration ?? Duration(milliseconds: kDefaultTransactionDuration),
        super(key: key);

  TransformerPageView.cube({
    @required this.controller,
    @required this.index,
    @required this.onPageChanged,
    @required this.itemCount,
    @required this.itemBuilder,
    this.pageController,
    this.physics,
  })  : this.loop = true,
        this.viewportFraction = 1.0,
        this.duration = Duration(milliseconds: kDefaultTransactionDuration),
        this.pageSnapping = true,
        this.scrollDirection = Axis.horizontal,
        this.curve = Curves.ease,
        this.transformer = CubeTransformer();

  @override
  State<StatefulWidget> createState() => _TransformerPageViewState();
}

class _TransformerPageViewState extends State<TransformerPageView> {
  ChangeNotifier _controller;
  PageTransformer _transformer;
  TransformerPageController _pageController;

  Size _size;
  int _activeIndex;
  double _currentPixels;
  bool _done = false;
  int _fromIndex;

  Widget _buildItemNormal(BuildContext context, int index) {
    int renderIndex = _pageController.getRenderIndexFromRealIndex(index);
    Widget child = widget.itemBuilder(context, renderIndex);
    return child;
  }

  Widget _buildItem(BuildContext context, int index) {
    return AnimatedBuilder(
        animation: _pageController,
        builder: (BuildContext c, Widget w) {
          int renderIndex = _pageController.getRenderIndexFromRealIndex(index);
          Widget child;
          if (widget.itemBuilder != null) child = widget.itemBuilder(context, renderIndex);
          if (child == null) child = Container();
          if (_size == null) return child ?? Container();

          double position;
          double page = _pageController.realPage;
          if (_transformer.reverse) {
            position = page - index;
          } else {
            position = index - page;
          }
          position *= widget.viewportFraction;

          TransformInfo info = TransformInfo(
              index: renderIndex,
              width: _size.width,
              height: _size.height,
              position: position.clamp(-1.0, 1.0),
              activeIndex: _pageController.getRenderIndexFromRealIndex(_activeIndex),
              fromIndex: _fromIndex,
              forward: _pageController.position.pixels - _currentPixels >= 0,
              done: _done,
              scrollDirection: widget.scrollDirection,
              viewportFraction: widget.viewportFraction);
          return _transformer.transform(child, info);
        });
  }

  double _calcCurrentPixels() {
    _currentPixels = _pageController.getRenderIndexFromRealIndex(_activeIndex) * _pageController.position.viewportDimension * widget.viewportFraction;
    return _currentPixels;
  }

  @override
  Widget build(BuildContext context) {
    IndexedWidgetBuilder builder = _transformer == null ? _buildItemNormal : _buildItem;
    Widget child = PageView.builder(
      itemBuilder: builder,
      itemCount: _pageController.getRealItemCount(),
      onPageChanged: _onIndexChanged,
      controller: _pageController,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      pageSnapping: widget.pageSnapping,
      reverse: _pageController.reverse,
    );
    if (_transformer == null) return child;

    return NotificationListener(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollStartNotification) {
            _calcCurrentPixels();
            _done = false;
            _fromIndex = _activeIndex;
          } else if (notification is ScrollEndNotification) {
            _calcCurrentPixels();
            _fromIndex = _activeIndex;
            _done = true;
          }
          return false;
        },
        child: child);
  }

  void _onIndexChanged(int index) {
    _activeIndex = index;
    if (widget.onPageChanged != null) {
      widget.onPageChanged(_pageController.getRenderIndexFromRealIndex(index));
    }
  }

  void _onGetSize(_) {
    Size size;
    if (context == null) {
      onGetSize(size);
      return;
    }

    RenderObject renderObject = context.findRenderObject();
    if (renderObject != null) {
      Rect bounds = renderObject.paintBounds;
      if (bounds != null) {
        size = bounds.size;
      }
    }
    _calcCurrentPixels();
    onGetSize(size);
  }

  void onGetSize(Size size) {
    if (mounted) setState(() => _size = size);
  }

  @override
  void initState() {
    _transformer = widget.transformer;
    _pageController = widget.pageController;
    if (_pageController == null) {
      _pageController = TransformerPageController(
          initialPage: widget.index,
          itemCount: widget.itemCount,
          loop: widget.loop,
          reverse: widget.transformer == null ? false : widget.transformer.reverse);
    }

    _fromIndex = _activeIndex = _pageController.initialPage;
    _controller = getNotifier();
    if (_controller != null) _controller.addListener(onChangeNotifier);

    super.initState();
  }

  @override
  void didUpdateWidget(TransformerPageView oldWidget) {
    _transformer = widget.transformer;
    int index = widget.index ?? 0;
    bool created = false;
    if (_pageController != widget.pageController) {
      if (widget.pageController != null) {
        _pageController = widget.pageController;
      } else {
        created = true;
        _pageController = TransformerPageController(
          initialPage: widget.index,
          itemCount: widget.itemCount,
          loop: widget.loop,
          reverse: widget.transformer == null ? false : widget.transformer.reverse,
        );
      }
    }

    if (_pageController.getRenderIndexFromRealIndex(_activeIndex) != index) {
      _fromIndex = _activeIndex = _pageController.initialPage;
      if (!created) {
        int initPage = _pageController.getRealIndexFromRenderIndex(index);
        _pageController.animateToPage(initPage, duration: widget.duration, curve: widget.curve);
      }
    }
    if (_transformer != null) WidgetsBinding.instance.addPostFrameCallback(_onGetSize);

    if (_controller != getNotifier()) {
      if (_controller != null) {
        _controller.removeListener(onChangeNotifier);
      }
      _controller = getNotifier();
      if (_controller != null) {
        _controller.addListener(onChangeNotifier);
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    if (_transformer != null) WidgetsBinding.instance.addPostFrameCallback(_onGetSize);
    super.didChangeDependencies();
  }

  ChangeNotifier getNotifier() => widget.controller;

  int _calcNextIndex(bool next) {
    int currentIndex = _activeIndex;
    if (_pageController.reverse) {
      if (next) {
        currentIndex--;
      } else {
        currentIndex++;
      }
    } else {
      if (next) {
        currentIndex++;
      } else {
        currentIndex--;
      }
    }

    if (!_pageController.loop) {
      if (currentIndex >= _pageController.itemCount) {
        currentIndex = 0;
      } else if (currentIndex < 0) {
        currentIndex = _pageController.itemCount - 1;
      }
    }
    return currentIndex;
  }

  void onChangeNotifier() {
    int event = widget.controller.event;
    int index;
    switch (event) {
      case IndexController.MOVE:
        {
          index = _pageController.getRealIndexFromRenderIndex(widget.controller.index);
        }
        break;
      case IndexController.PREVIOUS:
      case IndexController.NEXT:
        {
          index = _calcNextIndex(event == IndexController.NEXT);
        }
        break;
      default:
        return;
    }
    if (widget.controller.animation) {
      _pageController.animateToPage(index, duration: widget.duration, curve: widget.curve ?? Curves.ease).whenComplete(widget.controller.complete);
    } else {
      _pageController.jumpToPage(index);
      widget.controller.complete();
    }
  }

  void dispose() {
    super.dispose();
    if (_controller != null) {
      _controller.removeListener(onChangeNotifier);
    }
  }
}
