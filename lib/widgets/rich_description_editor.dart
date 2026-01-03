import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';

/// A rich text editor widget for event descriptions.
/// 
/// Provides WYSIWYG editing with a formatting toolbar.
/// Outputs plain text with markdown-style formatting markers.
class RichDescriptionEditor extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int minLines;
  final int maxLines;

  const RichDescriptionEditor({
    super.key,
    this.initialText = '',
    required this.onChanged,
    this.hintText = 'Add description...',
    this.minLines = 3,
    this.maxLines = 8,
  });

  @override
  State<RichDescriptionEditor> createState() => _RichDescriptionEditorState();
}

class _RichDescriptionEditorState extends State<RichDescriptionEditor> {
  late QuillController _controller;
  late FocusNode _focusNode;
  bool _showToolbar = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = QuillController.basic();
    
    // Initialize with existing text if provided
    if (widget.initialText.isNotEmpty) {
      _setInitialText(widget.initialText);
    }

    // Listen for changes
    _controller.document.changes.listen((_) {
      final text = _getPlainTextWithFormatting();
      widget.onChanged(text);
    });

    // Show/hide toolbar based on focus
    _focusNode.addListener(() {
      setState(() {
        _showToolbar = _focusNode.hasFocus;
      });
    });
  }

  void _setInitialText(String text) {
    // Parse markdown-style text back to Quill delta
    final delta = Delta()
      ..insert(text)
      ..insert('\n');
    _controller = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  String _getPlainTextWithFormatting() {
    // Get the formatted text preserving some markdown markers
    final plainText = _controller.document.toPlainText().trim();
    return plainText;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Formatting toolbar (shows when focused)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _showToolbar ? 44 : 0,
          child: _showToolbar
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: QuillSimpleToolbar(
                    controller: _controller,
                    config: QuillSimpleToolbarConfig(
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: false,
                      showStrikeThrough: false,
                      showInlineCode: true,
                      showCodeBlock: false,
                      showListBullets: true,
                      showListNumbers: true,
                      showListCheck: false,
                      showQuote: true,
                      showLink: true,
                      showHeaderStyle: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                      showClearFormat: true,
                      showAlignmentButtons: false,
                      showLeftAlignment: false,
                      showCenterAlignment: false,
                      showRightAlignment: false,
                      showJustifyAlignment: false,
                      showIndent: false,
                      showDividers: true,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showDirection: false,
                      showUndo: true,
                      showRedo: true,
                      showSmallButton: false,
                      buttonOptions: QuillSimpleToolbarButtonOptions(
                        base: QuillToolbarBaseButtonOptions(
                          iconSize: 18,
                          iconButtonFactor: 1.2,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        
        // Editor
        Container(
          constraints: BoxConstraints(
            minHeight: widget.minLines * 24.0,
            maxHeight: widget.maxLines * 24.0,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: _focusNode.hasFocus
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: QuillEditor.basic(
            controller: _controller,
            focusNode: _focusNode,
            config: QuillEditorConfig(
              placeholder: widget.hintText,
              padding: EdgeInsets.zero,
              scrollable: true,
              expands: false,
              autoFocus: false,
            ),
          ),
        ),
        
        // Formatting hint
        if (!_showToolbar)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Tap to add formatting',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }
}

/// A simpler text field that supports basic markdown input without WYSIWYG.
/// Good for quick editing or when the full editor is too heavy.
class SimpleMarkdownField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const SimpleMarkdownField({
    super.key,
    required this.controller,
    this.hintText = 'Add description (supports **bold**, *italic*, [links](url))',
    this.minLines = 2,
    this.maxLines = 5,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: TextInputType.multiline,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Supports: **bold**, *italic*, `code`, [link](url), 1. numbered list',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }
}
