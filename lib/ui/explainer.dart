// An explanation you walk through: the picture changes, one line of words
// underneath, and a question part-way that must be answered before the next
// step appears. Thinking first, being shown second.
import "package:flutter/material.dart";
import "../blocks.dart";
import "../theme.dart";
import "manipulatives.dart";
import "pictures.dart";

class Walkthrough extends StatefulWidget {
  const Walkthrough({super.key, required this.explainer, required this.onSend, this.disabled = false});
  final Explainer explainer;
  final void Function(String text) onSend;
  final bool disabled;

  @override
  State<Walkthrough> createState() => _WalkthroughState();
}

class _WalkthroughState extends State<Walkthrough> {
  int i = 0;
  final answered = <int>{};
  final reply = TextEditingController();

  @override
  void dispose() { reply.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final steps = widget.explainer.steps;
    final step = steps[i];
    final last = i == steps.length - 1;
    final waiting = (step.ask != null || step.doIt != null) && !answered.contains(i);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? C.dPaper : C.paper,
        border: Border.all(color: dark ? C.dLine : C.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.explainer.title,
              style: Theme.of(context).textTheme.titleMedium)),
          for (var n = 0; n < steps.length; n++)
            Container(
              width: n == i ? 18 : 7, height: 7,
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                color: n == i ? C.blue : (n < i ? C.blueSoft : C.line),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ]),
        const SizedBox(height: 10),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: ValueKey(i),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: dark ? C.dGround : C.ground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              if (step.show != null) Picture(spec: step.show!),
              if (step.show != null) const SizedBox(height: 10),
              Text(step.say, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
            ]),
          ),
        ),

        if (step.ask != null && !answered.contains(i)) ...[
          const SizedBox(height: 10),
          Text(step.ask!, style: const TextStyle(fontWeight: FontWeight.w700, color: C.blue)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              controller: reply,
              decoration: const InputDecoration(hintText: "Type what you think…"),
              onSubmitted: (_) => _answer(step),
            )),
            const SizedBox(width: 8),
            FilledButton(onPressed: widget.disabled ? null : () => _answer(step), child: const Text("Answer")),
          ]),
        ],

        if (step.doIt != null && !answered.contains(i))
          Manipulative(
            spec: step.doIt!,
            disabled: widget.disabled,
            onSend: (t) {
              widget.onSend(t);
              setState(() { answered.add(i); if (!last) i++; });
            },
          ),

        const SizedBox(height: 10),
        Row(children: [
          TextButton(onPressed: i == 0 ? null : () => setState(() => i--), child: const Text("← Back")),
          const SizedBox(width: 8),
          if (!last)
            FilledButton(
              onPressed: waiting ? null : () => setState(() => i++),
              child: Text(waiting ? "Answer first 🙂" : "Next →"),
            )
          else ...[
            FilledButton(
              onPressed: widget.disabled || waiting
                  ? null
                  : () => widget.onSend('I went through "${widget.explainer.title}" and I understand it now.'),
              child: const Text("I get it! 🌟"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.disabled
                  ? null
                  : () => widget.onSend('I went through "${widget.explainer.title}" but I\'m still confused.'),
              child: const Text("Still confused"),
            ),
          ],
          const Spacer(),
          Text("${i + 1} / ${steps.length}", style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]),
    );
  }

  void _answer(ExplainStep step) {
    final t = reply.text.trim();
    if (t.isEmpty) return;
    widget.onSend("${step.ask} — I think $t");
    reply.clear();
    setState(() {
      answered.add(i);
      if (i < widget.explainer.steps.length - 1) i++;
    });
  }
}
