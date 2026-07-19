# Mermaid diagrams

A simple top-down flowchart with labeled edges:

```mermaid
graph TD
A[Start] --> B[Load config]
B -->|ok| C[Render]
B -->|error| D[Report]
C --> E[Done]
D --> E
```

A left-to-right flowchart using a subgraph:

```mermaid
graph LR
A[Client] --> B
subgraph Server
B[API] --> C[DB]
end
```

Node shapes other than `[...]`, with multi-line and quoted labels. Every shape
is drawn as a rectangle, but its delimiters are stripped from the label:

```mermaid
flowchart LR
A["formula row:\ninput + gold formula"] --> B["teacher\nrecast question"]
B --> C{"verify (deterministic):\ncomponents ↔ sub-queries\nbijection; NL-only"}
C -->|pass| D(["finalize"])
C -->|"fail, retries < 2\n(with feedback)"| B
C -->|fail twice| E((rejected))
```

A sequence diagram:

```mermaid
sequenceDiagram
Alice->>Bob: Request
Bob-->>Alice: Response
```

An unsupported diagram type falls back to a highlighted code block:

```mermaid
pie title Pets
"Dogs": 3
"Cats": 2
```
