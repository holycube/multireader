"""
Syntactic chunk boundary detector using spaCy.
Returns character offsets where new chunks begin (excludes position 0).
"""
import json

_nlp = None


def _get_nlp():
    global _nlp
    if _nlp is None:
        import spacy
        _nlp = spacy.load("en_core_web_sm")
    return _nlp


def get_chunk_boundaries(text: str) -> str:
    """
    Returns JSON-encoded sorted list of character offsets marking chunk boundaries.
    A boundary is placed at the start of:
    - relative clauses (that/which/who...)
    - adverbial clauses (because/when/although...)
    - verb-attached prepositional phrases (PP modifying verb, not noun)
    Sentence boundaries are included only when mid-paragraph.
    """
    if not text or not text.strip():
        return "[]"

    nlp = _get_nlp()
    doc = nlp(text)
    boundaries = set()

    for sent in doc.sents:
        # Add sentence boundaries (skip first sentence start = position 0)
        if sent.start_char > 0:
            boundaries.add(sent.start_char)

        for token in sent:
            # Relative clause: "the project [that no one thought...]"
            if token.dep_ in ("relcl", "acl") and token.left_edge.idx > 0:
                boundaries.add(token.left_edge.idx)

            # Adverbial clause: "[Because she left,] he stayed"
            elif token.dep_ == "advcl" and token.left_edge.idx > 0:
                boundaries.add(token.left_edge.idx)

            # Prepositional phrase modifying a VERB: "finished [before the deadline]"
            elif (
                token.dep_ == "prep"
                and token.head.pos_ in ("VERB", "AUX")
                and token.idx > 0
            ):
                boundaries.add(token.idx)

            # Participial / non-finite clause
            elif token.dep_ in ("advcl", "xcomp") and token.left_edge.idx > 0:
                boundaries.add(token.left_edge.idx)

    boundaries.discard(0)
    return json.dumps(sorted(boundaries))
