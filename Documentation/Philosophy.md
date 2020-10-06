# Lucid - Philosophy

Lucid is a Swift library for building robust data layers for applications.

- **Declarative**: Lucid makes it easy to declare complex data models and provides the tools to use it with plain Swift code.

- **Plug-and-play**: Use the stores which suit your data flow the best or write your own. Lucid gives you the infrastructure to seamlessly integrate the technologies you want to use.

- **Adaptability**: Built to fit most kinds of standard and non-standard server APIs, Lucid abstracts away server-side structural decisions by providing a resource oriented universal client-side API.

---

At Scribd, our iOS application has been a huge part of our business since almost the beginning. For nearly ten years, developers have been adding features to same codebase, which became harder to maintain over time. We identified that the main hurdle was the lack of standardized data flow. In order to fix that, we decided to develop a suit of tools to help us follow a standardized way of declaring entities, but also pulling them from one or more remotes and storing them to one or more local stores. This is how Lucid was born.

Hence, the philosophy behind Lucid is to allow developers to easily declare business entities and provide the tools to interact with them through a unified API. Because a codebase like we have at Scribd uses a multitude of methods to handle data, Lucid needs to be flexible and adaptable to many kind of data flows while abstracting away the their complexity.
