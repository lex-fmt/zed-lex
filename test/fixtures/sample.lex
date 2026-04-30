Sample Lex Document for Query Smoke Tests:
A self-contained fixture exercising every node type the queries care about

This file is parsed by scripts/test-queries.sh and the bats suite to
confirm each .scm query in languages/lex/ at least matches without
erroring. It does NOT need to be semantically meaningful — only that
every relevant CST node appears at least once.

1. Sessions and Subsessions

    A nested session shows up as @title in highlights and as a separate
    item in outline.

    1.1 A subsection

        Definition Subject:
            A definition body. Definitions are @property in Zed.

        ::: another note inline :::

2. Inline Formatting

    This paragraph contains **strong** text, _emphasis_, `inline code`,
    $math$, and an escape\* sequence.

    A reference to [a session][1.1], a citation [@smith2020], a URL
    <https://example.org>, a file ref <./other.lex>, and a TODO\
    placeholder [tocome].

3. Lists

    - First bullet
    - Second bullet
    1. First numbered
    2. Second numbered
    a) lettered
    b) lettered

4. Tables

    Status Overview:
        | Name | Count | Notes |
        | ---- | ----- | ----- |
        | one  | 1     | first |
        | two  | 2     | >>    |

5. Verbatim with Python Injection

    Snippet:
        def greet(name):
            return f"hello, {name}"
    :: python ::

6. Verbatim with JSON Injection

    Config:
        {"key": "value", "n": 42}
    :: json ::

7. Plain Verbatim

    Plain Text:
        No language tag — just literal content.
    :: text ::

:: note ::
This is an annotation block. It's metadata, not prose.
:: ::
