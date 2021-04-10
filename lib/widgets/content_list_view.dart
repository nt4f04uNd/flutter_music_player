/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'package:flutter/material.dart';
import 'package:nt4f04unds_widgets/nt4f04unds_widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sweyer/sweyer.dart';

/// Signature used for the [SongListView.currentTest] and others in this file.
///
/// The is [index] is index of the song.
typedef _CurrentTest = bool Function(int index);

/// Creates a list of content.
/// 
/// Picks some value based on the provided `T` type of [Content].
/// 
/// Instead of `T`, you can explicitly specify [contentType].
class ContentListView<T extends Content> extends StatelessWidget {
  const ContentListView({
    Key key,
    @required this.list,
    this.itemScrollController,
    this.selectionController,
    this.onItemTap,
    this.contentType,
  }) : super(key: key);


  /// Content list.
  final List<Content> list;

  final SelectionController<SelectionEntry<T>> selectionController;

  final ItemScrollController itemScrollController;

  /// Callback to be called on item tap.
  final VoidCallback onItemTap;

  /// An explicit content type.
  final Type contentType;

  @override
  Widget build(BuildContext context) {
    return contentPick<T, Widget Function()>(
      contentType: contentType,
      song: () => SongListView(
        songs: list,
        selectionController: selectionController,
        onItemTap: onItemTap,
        itemScrollController: itemScrollController,
      ),
      album: () => AlbumListView(
        albums: list,
        selectionController: selectionController,
        onItemTap: onItemTap,
        itemScrollController: itemScrollController,
      ),
    )();
  }
}

/// Renders a list view of [SongTile]s from provided [songs] array.
class SongListView extends StatefulWidget {
  const SongListView({
    Key key,
    @required this.songs,
    this.itemScrollController,
    this.leading,
    this.currentTest,
    this.songTileVariant = SongTileVariant.albumArt,
    this.songClickBehavior = SongClickBehavior.play,
    this.onItemTap,
    this.onScrollbarDragStart,
    this.onScrollbarDragEnd,
    this.scrollbar = ScrollbarType.none,
    this.selectionController,
    this.padding,
    this.physics = const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
  }) : super(key: key);

  final List<Song> songs;
  
  final ItemScrollController itemScrollController;

  /// A widget to build before all items.
  final Widget leading;

  /// Passed to [SongTile.currentTest].
  final _CurrentTest currentTest;

  /// Passed to [SongTile.variant].
  final SongTileVariant songTileVariant;

  /// Passed to [SongTile.clickBehavior].
  final SongClickBehavior songClickBehavior;

  /// Called on item tap.
  final VoidCallback onItemTap;

  /// Fires when user starts dragging [ScrollbarType.draggable].
  final VoidCallback onScrollbarDragStart;

  /// Fires when user starts dragging [ScrollbarType.draggable].
  final VoidCallback onScrollbarDragEnd;

  /// Indicates what scrollbar to use.
  final ScrollbarType scrollbar;

  /// If specified, list will be built as [new SongTile.selectable],
  /// otherwise [new SongTile] is used. 
  final SelectionController<SelectionEntry> selectionController;

  /// The amount of space by which to inset the children.
  final EdgeInsetsGeometry padding;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// See [ScrollView.physics].
  final ScrollPhysics physics;

  /// Index of an item to initially align within the viewport.
  final int initialScrollIndex;

  /// Determines where the leading edge of the item at [initialScrollIndex]
  /// should be placed.
  final double initialAlignment;

  @override
  _SongListViewState createState() => _SongListViewState();
}

class _SongListViewState extends State<SongListView> {
  bool get selectable => widget.selectionController != null;

  ItemScrollController itemScrollController;

  @override
  void initState() { 
    super.initState();
    itemScrollController = widget.itemScrollController;
    if (itemScrollController == null && widget.scrollbar == ScrollbarType.draggable) {
      itemScrollController = ItemScrollController();
    }
  }

  @override
  void didUpdateWidget(covariant SongListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemScrollController != widget.itemScrollController || oldWidget.scrollbar != widget.scrollbar) {
      if (widget.itemScrollController == null && widget.scrollbar == ScrollbarType.draggable) {
        itemScrollController ??= ItemScrollController();
      } else {
        itemScrollController = null;
      }
    }
  }

  void _handleDragStart(double progress, double barPadHeight) {
    widget.onScrollbarDragStart?.call();
  }

  void _handleDragEnd(double progress, double barPadHeight) {
    widget.onScrollbarDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.songs;
    final child = SingleTouchRecognizerWidget(
      child: ScrollablePositionedList.builder(
        itemScrollController: widget.itemScrollController ?? itemScrollController,
        itemCount: widget.leading != null ? items.length + 1 : items.length,
        physics: widget.physics,
        padding: widget.padding,
        initialScrollIndex: widget.initialScrollIndex,
        initialAlignment: widget.initialAlignment,
        itemBuilder: (context, index) {
          if (widget.leading != null) {
            if (index == 0) {
              return widget.leading;
            }
            index--;
          }
          final item = items[index];
          final currentTest = widget.currentTest != null ? () => widget.currentTest(index): null;
          if (selectable) {
            return SongTile.selectable(
              index: index,
              song: item,
              selectionController: widget.selectionController,
              clickBehavior: widget.songClickBehavior,
              variant: widget.songTileVariant,
              currentTest: currentTest,
              selected: widget.selectionController.data.contains(SelectionEntry<Song>(index: index)),
              onTap: widget.onItemTap,
            );
          }
          return SongTile(
            song: item,
            currentTest: currentTest,
            clickBehavior: widget.songClickBehavior,
            variant: widget.songTileVariant,
            onTap: widget.onItemTap,
          );
        },
      ),
    );
    switch (widget.scrollbar) {
      case ScrollbarType.none:
        return child;
      case ScrollbarType.notDraggable:
        return NFScrollbar(child: child);
      case ScrollbarType.draggable:
        return JumpingDraggableScrollbar.songs(
          onDragStart: _handleDragStart,
          onDragEnd: _handleDragEnd,
          itemCount: items.length,
          itemScrollController: itemScrollController,
          labelBuilder: (context, progress, barPadHeight, jumpIndex) {
            return NFScrollLabel(
              text: items[(jumpIndex - 1).clamp(0.0, items.length - 1).round()]
                  .title[0]
                  .toUpperCase(),
            );
          },
          child: child,
        );
      default:
        return null;
    }
  }
}

/// Renders a list view of [AlbumTiles]s from provided [albums] array.
class AlbumListView extends StatefulWidget {
  const AlbumListView({
    Key key,
    @required this.albums,
    this.itemScrollController,
    this.leading,
    this.currentTest,
    this.onItemTap,
    this.onScrollbarDragStart,
    this.onScrollbarDragEnd,
    this.scrollbar = ScrollbarType.none,
    this.selectionController,
    this.padding,
    this.physics = const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
  }) : super(key: key);

  final List<Album> albums;
  
  final ItemScrollController itemScrollController;

  /// A widget to build before all items.
  final Widget leading;

  /// Passed to [AlbumTile.currentTest].
  final _CurrentTest currentTest;

  /// Called on item tap.
  final VoidCallback onItemTap;

  /// Fires when user starts dragging [ScrollbarType.draggable].
  final VoidCallback onScrollbarDragStart;

  /// Fires when user starts dragging [ScrollbarType.draggable].
  final VoidCallback onScrollbarDragEnd;

  /// Indicates what scrollbar to use.
  final ScrollbarType scrollbar;

  /// If specified, list will be built as [new AlbumTile.selectable],
  /// otherwise [new AlbumTile] is used. 
  final SelectionController<SelectionEntry> selectionController;

  /// The amount of space by which to inset the children.
  final EdgeInsetsGeometry padding;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// See [ScrollView.physics].
  final ScrollPhysics physics;

  /// Index of an item to initially align within the viewport.
  final int initialScrollIndex;

  /// Determines where the leading edge of the item at [initialScrollIndex]
  /// should be placed.
  final double initialAlignment;

  @override
  _AlbumListViewState createState() => _AlbumListViewState();
}

class _AlbumListViewState extends State<AlbumListView> {
  bool get selectable => widget.selectionController != null;

  ItemScrollController itemScrollController;

  @override
  void initState() { 
    super.initState();
    itemScrollController = widget.itemScrollController;
    if (itemScrollController == null && widget.scrollbar == ScrollbarType.draggable) {
      itemScrollController = ItemScrollController();
    }
  }

  @override
  void didUpdateWidget(covariant AlbumListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemScrollController != widget.itemScrollController || oldWidget.scrollbar != widget.scrollbar) {
      if (widget.itemScrollController == null && widget.scrollbar == ScrollbarType.draggable) {
        itemScrollController ??= ItemScrollController();
      } else {
        itemScrollController = null;
      }
    }
  }

  void _handleDragStart(double progress, double barPadHeight) {
    widget.onScrollbarDragStart?.call();
  }

  void _handleDragEnd(double progress, double barPadHeight) {
    widget.onScrollbarDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.albums;
    final child = SingleTouchRecognizerWidget(
      child: ScrollablePositionedList.builder(
        itemScrollController: widget.itemScrollController ?? itemScrollController,
        itemCount: widget.leading != null ? items.length + 1 : items.length,
        physics: widget.physics,
        padding: widget.padding,
        initialScrollIndex: widget.initialScrollIndex,
        initialAlignment: widget.initialAlignment,
        itemBuilder: (context, index) {
          if (widget.leading != null) {
            if (index == 0) {
              return widget.leading;
            }
            index--;
          }
          final item = items[index];
          final currentTest = widget.currentTest != null ? () => widget.currentTest(index): null;
          if (selectable) {
            return AlbumTile.selectable(
              index: index,
              album: item,
              currentTest: currentTest,
              onTap: widget.onItemTap,
              selected: widget.selectionController.data.contains(SelectionEntry<Album>(index: index)),
              selectionController: widget.selectionController,
            );
          }
          return AlbumTile(
            album: item,
            onTap: widget.onItemTap,
            currentTest: currentTest,
          );
        },
      ),
    );
    switch (widget.scrollbar) {
      case ScrollbarType.none:
        return child;
      case ScrollbarType.notDraggable:
        return NFScrollbar(child: child);
      case ScrollbarType.draggable:
        return JumpingDraggableScrollbar.albums(
          onDragStart: _handleDragStart,
          onDragEnd: _handleDragEnd,
          itemCount: items.length,
          itemScrollController: itemScrollController,
           labelBuilder: (context, progress, barPadHeight, jumpIndex) {
            return NFScrollLabel(
              text: items[(jumpIndex - 1).clamp(0.0, items.length - 1).round()]
                  .album[0]
                  .toUpperCase(),
            );
          },
          child: child,
        );
      default:
        return null;
    }
  }
}
