import 'dart:math' as math;

import 'package:calsee_themes/calc_theme.dart';
import 'package:calsee_themes/widgets/calsee_key.dart';
import 'package:calsee_themes/widgets/calsee_surfaces.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Form controls drawn by the current theme. They are built from key faces,
// so they wear each family's look, and from the face's own label colour,
// which the guardrails keep ≥ 4.5:1 against the face: a selected control
// wears the accent face (KeyRole.equals), an unselected one the plain face
// (KeyRole.digit), and every mark (tick, dot, thumb, chevron) is drawn in
// that face's label colour. Marks are painted, so apps need no icon font.

const Duration _motion = Duration(milliseconds: 180);

Duration _duration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : _motion;

/// The face a control wears: the accent when [selected].
KeyRole _role(bool selected) => selected ? KeyRole.equals : KeyRole.digit;

/// A control's caption: [label] beside it, in the text colour for where it
/// sits (backdrop or display panel).
class _Captioned extends StatelessWidget {
  const _Captioned({
    required this.control,
    required this.label,
    required this.onTap,
  });

  final Widget control;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return control;
    // The control dims itself when disabled; the caption dims with it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          control,
          const SizedBox(width: 12),
          Flexible(
            child: Opacity(
              opacity: onTap == null ? 0.45 : 1,
              child: Text(
                text,
                style: TextStyle(
                  color: CalseeTextColors.of(context).primary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A box that is ticked or not: the accent face with a tick when [value],
/// the plain face when not. Tapping it or its [label] calls [onChanged];
/// without [onChanged] it is disabled.
class CalseeCheckbox extends StatelessWidget {
  /// A checkbox of [size] logical pixels.
  const CalseeCheckbox({
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
    this.size = 32,
    super.key,
  });

  /// Whether the box is ticked.
  final bool value;

  /// Called with the new value; null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  /// Text beside the box (tapping it toggles too).
  final String? label;

  /// What screen readers announce; defaults to [label].
  final String? semanticLabel;

  /// The box's side.
  final double size;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    final toggle = change == null ? null : () => change(!value);
    return Semantics(
      container: true,
      checked: value,
      enabled: change != null,
      label: semanticLabel ?? label,
      onTap: toggle,
      excludeSemantics: true,
      child: _Captioned(
        label: label,
        onTap: toggle,
        control: SizedBox.square(
          dimension: size,
          child: CalseeKey(
            role: _role(value),
            semanticLabel: '',
            onPressed: toggle,
            builder: (context, style, shortSide) => value
                ? CustomPaint(
                    size: Size.square(shortSide * 0.56),
                    painter: _TickPainter(style.label),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// One choice of several: the accent face with a dot when [value] equals
/// [groupValue]. Tapping it or its [label] calls [onChanged] with [value].
class CalseeRadio<T> extends StatelessWidget {
  /// A radio button of [size] logical pixels.
  const CalseeRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
    this.semanticLabel,
    this.size = 32,
    super.key,
  });

  /// The value this button stands for.
  final T value;

  /// The selected value of the group.
  final T? groupValue;

  /// Called with [value] when chosen; null disables the button.
  final ValueChanged<T>? onChanged;

  /// Text beside the button (tapping it chooses too).
  final String? label;

  /// What screen readers announce; defaults to [label].
  final String? semanticLabel;

  /// The button's side.
  final double size;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final change = onChanged;
    final choose = change == null ? null : () => change(value);
    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: change != null,
      label: semanticLabel ?? label,
      onTap: choose,
      excludeSemantics: true,
      child: _Captioned(
        label: label,
        onTap: choose,
        control: SizedBox.square(
          dimension: size,
          child: CalseeKey(
            role: _role(selected),
            semanticLabel: '',
            onPressed: choose,
            // A ring, and a dot inside it when chosen: a radio in every
            // family, whatever the face's shape.
            builder: (context, style, shortSide) => Container(
              width: shortSide * 0.56,
              height: shortSide * 0.56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: style.label,
                  width: math.max(1.5, shortSide * 0.07),
                ),
              ),
              child: selected
                  ? Container(
                      width: shortSide * 0.24,
                      height: shortSide * 0.24,
                      decoration: BoxDecoration(
                        color: style.label,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// An on/off switch: a track wearing the accent face when [value] (the
/// plain face when not), with a thumb in the track's label colour that
/// slides across.
class CalseeSwitch extends StatelessWidget {
  /// A switch [width] by [height] logical pixels.
  const CalseeSwitch({
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
    this.width = 60,
    this.height = 34,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Text beside the switch (tapping it toggles too).
  final String? label;

  /// What screen readers announce; defaults to [label].
  final String? semanticLabel;

  /// The track's size.
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    final toggle = change == null ? null : () => change(!value);
    final duration = _duration(context);
    return Semantics(
      container: true,
      toggled: value,
      enabled: change != null,
      label: semanticLabel ?? label,
      onTap: toggle,
      excludeSemantics: true,
      child: _Captioned(
        label: label,
        onTap: toggle,
        control: SizedBox(
          width: width,
          height: height,
          child: CalseeKey(
            role: _role(value),
            semanticLabel: '',
            onPressed: toggle,
            builder: (context, style, shortSide) => Padding(
              padding: EdgeInsets.all(shortSide * 0.16),
              child: AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: shortSide * 0.62,
                  height: shortSide * 0.62,
                  decoration: BoxDecoration(
                    color: style.label,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of a few options, side by side: the chosen one wears the accent
/// face. Each segment is a key, so it has the family's press.
class CalseeSegmented<T> extends StatelessWidget {
  /// Segments for [options]: each a value and its label.
  const CalseeSegmented({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 48,
    this.spacing = 6,
    this.sizeFactor = 0.34,
    super.key,
  });

  /// The values and their labels, in order.
  final List<(T, String)> options;

  /// The chosen value.
  final T? selected;

  /// Called with the tapped value; null disables every segment.
  final ValueChanged<T>? onChanged;

  /// Height of the segments.
  final double height;

  /// Space between segments.
  final double spacing;

  /// Label size as a fraction of the segment height.
  final double sizeFactor;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (final (i, (value, text)) in options.indexed) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(
              child: Semantics(
                container: true,
                selected: value == selected,
                inMutuallyExclusiveGroup: true,
                child: CalseeKey.text(
                  text,
                  role: _role(value == selected),
                  sizeFactor: sizeFactor,
                  onPressed: change == null ? null : () => change(value),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A value between [min] and [max]: a plain-face track, filled in the
/// accent colour up to the value, with an accent-face thumb. Drag or tap
/// along it; with [divisions] it snaps to that many steps.
class CalseeSlider extends StatelessWidget {
  /// A slider [height] logical pixels tall that fills its width.
  const CalseeSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.semanticLabel,
    this.semanticFormatter,
    this.height = 40,
    super.key,
  }) : assert(min < max, 'min must be below max');

  /// The current value, from [min] to [max].
  final double value;

  /// Called while the value changes; null disables the slider.
  final ValueChanged<double>? onChanged;

  /// The range.
  final double min;
  final double max;

  /// Number of steps to snap to; null for a continuous slider.
  final int? divisions;

  /// What screen readers announce.
  final String? semanticLabel;

  /// How screen readers read a value; a percentage of the range by default.
  final String Function(double value)? semanticFormatter;

  /// The slider's height (the thumb's side).
  final double height;

  double get _fraction => ((value - min) / (max - min)).clamp(0.0, 1.0);

  double _snap(double fraction) {
    final steps = divisions;
    final f = fraction.clamp(0.0, 1.0);
    final snapped = steps == null || steps < 1
        ? f
        : (f * steps).round() / steps;
    return min + snapped * (max - min);
  }

  String _read(double v) =>
      semanticFormatter?.call(v) ??
      '${((v - min) / (max - min) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    final change = onChanged;
    final step = 1 / (divisions ?? 10);
    return Semantics(
      container: true,
      slider: true,
      enabled: change != null,
      label: semanticLabel,
      value: _read(value),
      increasedValue: _read(_snap(_fraction + step)),
      decreasedValue: _read(_snap(_fraction - step)),
      onIncrease: change == null ? null : () => change(_snap(_fraction + step)),
      onDecrease: change == null ? null : () => change(_snap(_fraction - step)),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final thumb = height;
            final travel = math.max<double>(1, width - thumb);
            void update(double dx) =>
                change?.call(_snap((dx - thumb / 2) / travel));
            final left = _fraction * travel;
            final track = height * 0.36;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: change == null
                  ? null
                  : (d) => update(d.localPosition.dx),
              onHorizontalDragStart: change == null
                  ? null
                  : (d) => update(d.localPosition.dx),
              onHorizontalDragUpdate: change == null
                  ? null
                  : (d) => update(d.localPosition.dx),
              child: Opacity(
                opacity: change == null ? 0.45 : 1,
                child: Stack(
                  children: [
                    Positioned(
                      left: thumb / 2 - track / 2,
                      right: thumb / 2 - track / 2,
                      top: (height - track) / 2,
                      height: track,
                      child: CalseeSurface(
                        role: KeyRole.digit,
                        builder: (context, style, shortSide) =>
                            const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: thumb / 2 - track / 2,
                      width: left + track,
                      top: (height - track) / 2,
                      height: track,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.equalsKey.fill,
                          borderRadius: BorderRadius.circular(track / 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      top: 0,
                      width: thumb,
                      height: thumb,
                      child: CalseeSurface(
                        role: KeyRole.equals,
                        builder: (context, style, shortSide) => Center(
                          child: Container(
                            width: shortSide * 0.28,
                            height: shortSide * 0.28,
                            decoration: BoxDecoration(
                              color: style.label,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A button showing the chosen item that opens a themed list of [items]
/// below it. The list is drawn in an [Overlay] (the app's, from
/// `WidgetsApp`), with the theme of where the dropdown sits.
class CalseeDropdown<T> extends StatefulWidget {
  /// A dropdown [height] logical pixels tall that fills its width.
  const CalseeDropdown({
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint = 'Choose',
    this.semanticLabel,
    this.height = 52,
    this.maxListHeight = 280,
    super.key,
  });

  /// The values and their labels, in order.
  final List<(T, String)> items;

  /// The chosen value; null shows [hint].
  final T? value;

  /// Called with the chosen value; null disables the dropdown.
  final ValueChanged<T>? onChanged;

  /// Shown when nothing is chosen.
  final String hint;

  /// What screen readers announce before the chosen item.
  final String? semanticLabel;

  /// Height of the button and of each item.
  final double height;

  /// The list scrolls beyond this height.
  final double maxListHeight;

  @override
  State<CalseeDropdown<T>> createState() => _CalseeDropdownState<T>();
}

class _CalseeDropdownState<T> extends State<CalseeDropdown<T>> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _group = Object();
  double _width = 0;

  String? get _chosen {
    for (final (value, text) in widget.items) {
      if (value == widget.value) return text;
    }
    return null;
  }

  void _close() {
    if (_portal.isShowing) setState(_portal.hide);
  }

  void _choose(T value) {
    _close();
    widget.onChanged?.call(value);
  }

  Widget _list(BuildContext context) {
    final theme = CalcTheme.of(context);
    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 6),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: TapRegion(
          groupId: _group,
          onTapOutside: (_) => _close(),
          child: Container(
            width: _width,
            constraints: BoxConstraints(maxHeight: widget.maxListHeight),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (value, text) in widget.items)
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: SizedBox(
                        height: widget.height,
                        child: Semantics(
                          container: true,
                          selected: value == widget.value,
                          child: CalseeKey(
                            role: _role(value == widget.value),
                            semanticLabel: text,
                            onPressed: () => _choose(value),
                            builder: (context, style, shortSide) => _Line(
                              text: text,
                              style: style,
                              size: shortSide * 0.34,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    final enabled = widget.onChanged != null && widget.items.isNotEmpty;
    final open = _portal.isShowing;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: [
        if (widget.semanticLabel != null) widget.semanticLabel!,
        chosen ?? widget.hint,
      ].join(', '),
      onTap: enabled ? () => setState(_portal.toggle) : null,
      excludeSemantics: true,
      child: CompositedTransformTarget(
        link: _link,
        child: TapRegion(
          groupId: _group,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: _list,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _width = constraints.maxWidth;
                return SizedBox(
                  height: widget.height,
                  child: CalseeKey(
                    role: KeyRole.function,
                    semanticLabel: '',
                    onPressed: enabled ? () => setState(_portal.toggle) : null,
                    builder: (context, style, shortSide) => _Line(
                      text: chosen ?? widget.hint,
                      style: style,
                      size: shortSide * 0.34,
                      faded: chosen == null,
                      trailing: AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: _duration(context),
                        child: CustomPaint(
                          size: Size.square(shortSide * 0.32),
                          painter: _ChevronPainter(style.label),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A section that opens and closes: a header key with [title] and a
/// chevron, and [child] below it when open.
class CalseeExpandable extends StatefulWidget {
  /// An expandable section, closed unless [initiallyExpanded].
  const CalseeExpandable({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.headerHeight = 52,
    super.key,
  });

  /// The header's text.
  final String title;

  /// Shown below the header when open.
  final Widget child;

  /// Whether it starts open.
  final bool initiallyExpanded;

  /// Called with the new state when the header is tapped.
  final ValueChanged<bool>? onExpansionChanged;

  /// Height of the header.
  final double headerHeight;

  @override
  State<CalseeExpandable> createState() => _CalseeExpandableState();
}

class _CalseeExpandableState extends State<CalseeExpandable> {
  late bool _open = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _open = !_open);
    widget.onExpansionChanged?.call(_open);
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          button: true,
          label: widget.title,
          hint: _open ? 'Collapse' : 'Expand',
          onTap: _toggle,
          excludeSemantics: true,
          child: SizedBox(
            height: widget.headerHeight,
            child: CalseeKey(
              role: KeyRole.function,
              semanticLabel: '',
              onPressed: _toggle,
              builder: (context, style, shortSide) => _Line(
                text: widget.title,
                style: style,
                size: shortSide * 0.34,
                trailing: AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: duration,
                  child: CustomPaint(
                    size: Size.square(shortSide * 0.32),
                    painter: _ChevronPainter(style.label),
                  ),
                ),
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            heightFactor: _open ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ExcludeFocus(
                excluding: !_open,
                child: ExcludeSemantics(excluding: !_open, child: widget.child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A text input on the plain face, in the theme's key font, with the
/// theme's focus ring while focused.
class CalseeTextField extends StatefulWidget {
  /// A text field [height] logical pixels tall that fills its width.
  const CalseeTextField({
    this.controller,
    this.focusNode,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.inputFormatters,
    this.height = 56,
    this.fontSize = 18,
    super.key,
  });

  /// The text; the field makes its own when null.
  final TextEditingController? controller;

  /// The field's focus; it makes its own when null.
  final FocusNode? focusNode;

  /// Shown while the field is empty.
  final String? hint;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autofocus;

  /// Whether the field takes input.
  final bool enabled;

  final List<TextInputFormatter>? inputFormatters;

  /// The field's height.
  final double height;

  /// Size of the text.
  final double fontSize;

  @override
  State<CalseeTextField> createState() => _CalseeTextFieldState();
}

class _CalseeTextFieldState extends State<CalseeTextField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;

  // Taps place the caret, drags select, as in a platform text field.
  late final _gestures = TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(CalseeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFocus = oldWidget.focusNode ?? _ownFocus;
    if (oldFocus != _focus) {
      oldFocus?.removeListener(_changed);
      _focus.addListener(_changed);
    }
    final oldController = oldWidget.controller ?? _ownController;
    if (oldController != _controller) {
      oldController?.removeListener(_changed);
      _controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_changed);
    _controller.removeListener(_changed);
    _ownFocus?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    final focused = _focus.hasFocus;
    final hint = widget.hint;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: SizedBox(
        height: widget.height,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.height * theme.keyCornerFraction,
            ),
            border: focused
                ? Border.all(
                    color: theme.focusRing,
                    width: theme.focusRingWidth,
                  )
                : null,
          ),
          child: CalseeSurface(
            role: KeyRole.digit,
            builder: (context, style, shortSide) {
              final text = TextStyle(
                color: style.label,
                fontSize: widget.fontSize,
                fontFamily: theme.keyFontFamily,
                fontWeight: style.labelWeightFor(
                  boldText: MediaQuery.boldTextOf(context),
                ),
              );
              return _gestures.buildGestureDetector(
                behavior: HitTestBehavior.translucent,
                child: Padding(
                  padding: calseeFaceInset(context, shortSide, min: 14),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Stack(
                      children: [
                        if (hint != null && _controller.text.isEmpty)
                          IgnorePointer(
                            child: Text(
                              hint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.copyWith(
                                color: style.label.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        EditableText(
                          key: editableTextKey,
                          rendererIgnoresPointer: true,
                          controller: _controller,
                          focusNode: _focus,
                          style: text,
                          cursorColor: style.label,
                          backgroundCursorColor: style.fill,
                          selectionColor: style.label.withValues(alpha: 0.3),
                          readOnly: !widget.enabled,
                          autofocus: widget.autofocus,
                          obscureText: widget.obscureText,
                          keyboardType: widget.keyboardType,
                          textInputAction: widget.textInputAction,
                          inputFormatters: widget.inputFormatters,
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One line of [text] in a key face's label colour and the theme's key
/// font, start-aligned, with an optional [trailing] mark at the end.
class _Line extends StatelessWidget {
  const _Line({
    required this.text,
    required this.style,
    required this.size,
    this.trailing,
    this.faded = false,
  });

  final String text;
  final KeyStyle style;
  final double size;
  final Widget? trailing;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    final mark = trailing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size * 0.9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: faded ? style.label.withValues(alpha: 0.7) : style.label,
                fontSize: size,
                fontFamily: theme.keyFontFamily,
                fontWeight: style.labelWeightFor(
                  boldText: MediaQuery.boldTextOf(context),
                ),
              ),
            ),
          ),
          if (mark != null) ...[SizedBox(width: size * 0.5), mark],
        ],
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.08, h * 0.54)
        ..lineTo(w * 0.38, h * 0.82)
        ..lineTo(w * 0.92, h * 0.2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, w * 0.16)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.15, h * 0.35)
        ..lineTo(w * 0.5, h * 0.7)
        ..lineTo(w * 0.85, h * 0.35),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, w * 0.13)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
