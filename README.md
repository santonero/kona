# ⛈️ Kona
> **Design by Behavior.** A Lean BDD Workflow for Ruby on Rails.

**Kona** is an opinionated Rails application template designed to enforce rigorous behavior-driven design principles. It creates an environment where **Intent** dictates implementation, and where tests serve as strict design contracts.

It replaces the default "flaky" system tests with a rock-solid, high-performance stack centered around **Playwright**.

## 📜 The Philosophy

Kona is the technical enforcement of the **[Designing by Behavior](DESIGNING_BY_BEHAVIOR.md)** doctrine.

## ⚡ The Kona Stack

This template architects your Rails app for immediate BDD execution:

*   **[Playwright](https://playwright.dev/):** Replaces Selenium. Its superior auto-wait and semantic locators (`get_by_role`) ensure tests rely on user-facing behavior, not brittle CSS classes.
*   **[RSpec](https://rspec.info/):** Configured for clean documentation output.
*   **[Guard](https://github.com/guard/guard):** Instant feedback loop on file save.
*   **FactoryBot:** Pre-wired for concise state setup.
*   **Hybrid Driver:** A custom configuration allowing Capybara to boot the server while Playwright handles the browser logic directly.

## 🚀 Installation

Start a new Rails project with the Kona workflow:

```bash
rails new my_app -m https://raw.githubusercontent.com/santonero/kona/main/kona.rb
```

### Post-Install (One-time setup)
To ensure Playwright can control the browsers:

```bash
sudo ./node_modules/.bin/playwright install-deps
```

## 🎓 The Workflow in Action

To write a spec in Kona is to adhere to the **Grammar of Intent**. You must structure your specification through a strict hierarchy:

*   **Behavioral Domain** (`RSpec.describe`)
    *   **Behavioral Capacity** (`describe`)
        *   **Situation** (`context`)
            *   **Behavioral Example** (`scenario` / `it`)

Here are the two patterns you must master.

### Pattern A: The Mutational Sync Anchor
*The "Gold Standard" for testing Commands.*

When testing a state mutation, we must ensure the action is complete before checking the database. **We do this by nesting the UI expectation INSIDE the change block.**

```ruby
# spec/system/products_spec.rb

RSpec.describe "Products management", type: :system do
  describe "Creating a product" do
    before { page.goto new_product_path }

    context "with valid parameters" do
      scenario "creates a new product" do
        page.get_by_label("Name").fill("A Nice Name")
        page.get_by_label("Quantity").fill("10")

        # HOLISTIC PROOF: State Mutation + Visible Communication
        expect do
          # 1. TRIGGER (The stimulus)
          page.get_by_role("button", name: "Create Product").click

          # 2. SYNC ANCHOR (Intermediate UI sync)
          expect(page.get_by_role("heading", name: "A Nice Name")).to be_visible
        end.to change(Product, :count).by(1) # 3. STATE LOCK (The mutation)

        # 4. VISIBLE PROOF (The full communication)
        expect(page.get_by_text("Product was created successfully")).to be_visible
        expect(page.get_by_text("Quantity: 10")).to be_visible
      end
    end

    context "with invalid parameters" do
      scenario "does not create a new product" do
        page.get_by_label("Name").fill("")
        page.get_by_label("Quantity").fill("10")

        # HOLISTIC PROOF: Rejection (No Mutation + UI Feedback)
        expect do
          # 1. TRIGGER
          page.get_by_role("button", name: "Create Product").click

          # 2. SYNC ANCHOR (Error feedback)
          expect(page.get_by_text("Name can't be blank")).to be_visible
        end.not_to change(Product, :count) # 3. STATE LOCK (Negative)

        # 4. VISIBLE PROOF (Form state)
        expect(page.get_by_label("Name")).to have_value("")
        expect(page.get_by_label("Quantity")).to have_value("10")
      end
    end
  end
end
```

### Pattern B: The Anchored Helper
*Use this to abstract repetitive behaviors across multiple contexts.*

If you extract a helper method, it **must** contain its own Sync Anchor. It must not return control until the UI has settled.

**The Helper:**
```ruby
# spec/support/system_spec_helpers.rb or similar
def add_to_cart(product)
  page.goto product_path(product)
  page.get_by_role("button", name: "Add to Cart").click

  # INTERNAL SYNC ANCHOR: Blocks until UI confirmation to prevent race conditions.
  expect(page.get_by_text("Product was added to your cart successfully")).to be_visible
end
```

**The Spec:**
```ruby
# spec/system/carts_spec.rb

RSpec.describe "Carts management", type: :system do
  describe "Adding a product to the cart" do
    let!(:product_A) { create(:product, name: "First Product", quantity: 2) }
    let!(:product_B) { create(:product, name: "Second Product", quantity: 2) }

    context "as an anonymous user" do
      context "who has no cart" do
        scenario "creates a new cart and adds the product" do
          expect do
            add_to_cart product_A
          end.to change(Cart, :count).by(1).and change(LineItem, :count).by(1)

          cart = Cart.last
          expect(cart.products).to include(product_A)
        end
      end

      context "who has a cart" do
        let!(:cart) { add_to_cart(product_A); Cart.last }

        scenario "adds the product to the cart" do
          expect do
            add_to_cart product_B
          end.to change(LineItem, :count).by(1).and not_change(Cart, :count)

          expect(cart.reload.products).to include(product_A, product_B)
        end
      end
    end

    context "as a logged-in user" do
      let!(:user) { create(:user) }
      before { login_as user }

      context "who has no cart" do
        scenario "creates a new cart for the user and adds the product" do
          expect do
            add_to_cart product_A
          end.to change { user.reload.cart }.from(nil).to(an_instance_of(Cart)).and change(LineItem, :count).by(1)

          expect(user.reload.cart.products).to include(product_A)
        end
      end

      context "who has a cart" do
        before { add_to_cart product_A }

        scenario "adds the product to the cart" do
          expect do
            add_to_cart product_B
          end.to change(LineItem, :count).by(1).and not_change(Cart, :count)

          expect(user.reload.cart.products).to include(product_A, product_B)
        end
      end
    end
  end
end
```

## 🏛️ The Architecture of Responsibility

Kona enforces strict boundaries between the Web and your Business Domain. Refactoring is not about shrinking code; it is about clarifying responsibility.

### I. The Controller is the Ferryman
It stands at the boundary. It knows nothing of your business rules.
*   **Its Role:** Translate the external protocol (HTTP) into identities (`current_user`, `params`), issue **a single command** to the Domain, and relay the outcome (HTML/JSON).
*   **The Red Line:** A Controller that contains an `if` evaluating a business rule (e.g., checking stock levels) usurps the Domain.

### II. The Model is the Domain Expert
It is the sole incarnation of your business. It is autonomous and responsible for its own integrity.
*   **Its Role:** Validate state, hide SQL complexity, and expose **behaviors** (Action Verbs) to mutate itself or its direct children.
*   **The Red Line:** A Model that reads Web context (`session`, `cookies`) or formats data for the screen (Currencies, Dates) is corrupted.

### III. The Law of "Tell, Don't Ask"
Never pull an object's internal structure apart to do its work for it. Command it to act.

**❌ Usurpation (The Controller does the work):**
```ruby
item = cart.line_items.find_or_initialize_by(product: product)
item.increment(:quantity)
item.save
```

**✅ Delegation (The Controller issues a command):**
```ruby
cart.add(product)
```

## 🛠️ Developer Experience

### `bundle exec guard`
Runs your tests automatically.
*   Edit a Controller? -> Runs related Request & System specs.
*   Edit a View? -> Runs related System specs.

### Screenshot on Failure
If a system test fails, a full-page screenshot is automatically saved to `tmp/playwright_screenshots`, capturing the exact state of the UI at the moment of failure.

---

⛈️ **Happy coding! Stay in the flow and design by behavior.**

## License
MIT