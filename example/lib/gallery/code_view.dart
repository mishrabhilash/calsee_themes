import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final _sources = <String, Future<String>>{};

/// The source at asset [path], fetched once. On the web each asset is a
/// network request, so the gallery starts them all at launch.
Future<String> loadSource(String path) =>
    _sources[path] ??= rootBundle.loadString(path);

/// A Dart source file with light syntax colouring and a copy button, on a
/// fixed dark panel so it reads the same in every theme.
class CodeView extends StatefulWidget {
  const CodeView({required this.path, super.key});

  /// Asset path of the source file (example/lib/...).
  final String path;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  late final Future<String> _source = loadSource(widget.path);
  bool _copied = false;

  static const _panel = Color(0xFF15171C);
  static const _plain = Color(0xFFE6E6E6);
  static const _muted = Color(0xFF8A8F98);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: FutureBuilder<String>(
      future: _source,
      builder: (context, snapshot) {
        final source = snapshot.data ?? '';
        final status = snapshot.hasError
            ? "Couldn't load this file. Reload the page to try again."
            : snapshot.hasData
            ? null
            : 'Loading source…';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.path.replaceFirst('lib/', 'example/lib/'),
                      style: const TextStyle(color: _muted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: source));
                      setState(() => _copied = true);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _copied ? 'Copied' : 'Copy',
                          style: const TextStyle(
                            color: _plain,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Text(
                  status,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text.rich(
                TextSpan(children: highlightDart(source)),
                style: const TextStyle(
                  color: _plain,
                  fontSize: 13,
                  height: 1.45,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

const _keyword = Color(0xFFC792EA);
const _string = Color(0xFFC3E88D);
const _comment = Color(0xFF7F8794);
const _type = Color(0xFF82AAFF);
const _number = Color(0xFFF78C6C);

const _keywords = {
  'abstract', 'async', 'await', 'break', 'case', 'class', 'const', //
  'continue', 'default', 'else', 'extends', 'false', 'final', 'for', //
  'if', 'import', 'in', 'late', 'new', 'null', 'override', 'required', //
  'return', 'static', 'super', 'switch', 'this', 'true', 'var', 'void', //
  'with', 'show', 'as', 'get', 'set',
};

final _token = RegExp(
  r'''(//[^\n]*)|('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")|(@?[A-Za-z_]\w*)|(\b\d+(?:\.\d+)?\b|0x[0-9A-Fa-f]+)''',
);

/// Spans colouring comments, strings, keywords, types and numbers.
List<TextSpan> highlightDart(String source) {
  final spans = <TextSpan>[];
  var at = 0;
  for (final m in _token.allMatches(source)) {
    if (m.start > at) spans.add(TextSpan(text: source.substring(at, m.start)));
    final text = m.group(0)!;
    final Color? color;
    if (m.group(1) != null) {
      color = _comment;
    } else if (m.group(2) != null) {
      color = _string;
    } else if (m.group(4) != null) {
      color = _number;
    } else if (_keywords.contains(text) || text.startsWith('@')) {
      color = _keyword;
    } else if (text[0].toUpperCase() == text[0] && text[0] != '_') {
      color = _type;
    } else {
      color = null;
    }
    spans.add(
      TextSpan(
        text: text,
        style: color == null ? null : TextStyle(color: color),
      ),
    );
    at = m.end;
  }
  if (at < source.length) spans.add(TextSpan(text: source.substring(at)));
  return spans;
}
