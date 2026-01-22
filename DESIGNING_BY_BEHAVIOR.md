### **Designing by Behavior**

**Preamble**

To design by behavior is to assert that software is not a collection of features, but an ensemble of responses. Our purpose is to articulate these responses before we implement them. Therefore, a behavior is not an aspiration, but the **complete and provable response of a subject to a scenario.**

---
**I. The Intent as the Source**

Every behavior begins not with code, but with **Intent**. We must first articulate the "why"—the business purpose or the user experience we seek to enable. Naming this intent transforms it from an intuition into a design principle that will guide all subsequent decisions.

**II. The Stage: Subject and Scenario**

Fueled by this Intent, we begin the act of design. We set the stage for the behavior by writing a **specification**—not a static document, but a living, **executable example**. This specification identifies its **Subject** (the entity under test) and the **Scenario** (the context and stimulus it receives).

**III. Behavior as a Holistic Response**

A behavior is the Subject's complete response to the Scenario. This response is not a single outcome, but a set of observable consequences which may include:
*   A visible communication (a return value or a UI update).
*   A fundamental mutation of state.
*   Interactions with other collaborating subjects.

Our primary duty is not merely to describe the visible surface of this response, but to specify and prove it **holistically**, ensuring that the visible outcome is a faithful reflection of the system's true state.

**IV. The Specification is the Design**

We do not design and then specify; the act of writing a specification **is** the act of design. The specification is the blueprint. It is the formal contract that defines the expected response before a single line of implementation is written. The code that follows is merely the fulfillment of this pre-established contract.

**V. Assertion and Evidence**

Every specification follows the immutable logic of a formal proof.
*   The **name** (`it` or `scenario`) is the **Assertion**: a clear claim that states the **primary purpose** of the behavior.
*   The **body** of the specification is the **Evidence**: a concrete, executable example that provides the irrefutable proof for the Assertion.

A behavior is only considered enabled when the evidence completely supports the assertion.

**VI. The Purpose Dictates the Proof**

We classify every behavior by its primary purpose: either to **alter the system** (Command) or to **observe the system** (Query).
*   For a **Command** (e.g., 'Create', 'Update'), the proof is incomplete without verifying the fundamental change of state.
*   For a **Query** (e.g., 'View', 'Search'), verifying the visible outcome is sufficient.

This distinction saves us from proving too little (risk) or proving too much (waste).

---

**Conclusion**

To adhere to this code is to treat software development as an act of precision and intellectual honesty. It is to accept that our role is not to write code that we hope is correct, but to write specifications that **prove,** beyond doubt, that the behavior we have designed is true, complete, and without ambiguity.