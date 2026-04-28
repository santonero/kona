<p align="center">
  <img src=".github/assets/konastorm.jpg" alt="Kona Storm Banner" width="100%">
</p>

# ⛈️ Kona
> **Design by Behavior.** A Lean BDD Workflow for Ruby on Rails.

**Kona** is an opinionated Rails application template built to enforce this workflow. It elevates the BDD cycle into a rigorous standard for provable design, ensuring that **Intent** dictates implementation.

## 🚀 Installation

Start a new Rails project with the Kona workflow:

```bash
rails new my_app -m https://raw.githubusercontent.com/santonero/kona/main/kona.rb
```

Enter your project and install the system dependencies required by Playwright (one-time setup):

```bash
cd my_app
sudo ./node_modules/.bin/playwright install-deps
```

## ⚡ The Kona Stack

Architected for immediate BDD execution and rock-solid reliability:

*   **[Playwright](https://playwright.dev/):** Replaces Selenium. Its superior auto-wait and semantic locators (`get_by_role`) ensure tests rely on user-facing behavior, not brittle CSS classes.
*   **[RSpec](https://rspec.info/):** Configured for clean documentation output.
*   **[Guard](https://github.com/guard/guard):** Instant feedback loop on file save.
*   **FactoryBot:** Pre-wired for concise state setup.
*   **Hybrid Driver:** Capybara boots the server; Playwright handles the browser logic directly.

## 📜 The Philosophy

Kona is the technical enforcement of the **[Designing by Behavior](DESIGNING_BY_BEHAVIOR.md)** doctrine.

## 🌀 The Kona Cycle

To build with Kona is to follow these four steps:

**a.** Determine the next most important behavior.

**b.** Describe it with an example, and watch it fail (**Red**).

**c.** Write the simplest code to make the example pass (**Green**).

**d.** **Refactor.**

---

## ⚙️ The Workflow in Action

To satisfy steps **a** and **b**, structure your specifications through this exact behavioral hierarchy:

```text
Behavioral Domain (RSpec.describe)
└── Behavioral Capacity (describe)
    └── Situation (context)
        └── Behavioral Example (scenario / it)
```

Here is the single pattern you must master to achieve Red and Green without flakiness.

### The Mutational Sync Anchor

Commands trigger asynchronous mutations. To prevent race conditions, we anchor the test to a visible UI change before measuring the database. We do this by nesting the UI expectation inside the expect { } block.

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

### Canonical Example: Comprehensive Cart Workflow

This spec demonstrates the full workflow in action—handling anonymous vs authenticated users, happy/sad paths, quantity increments, and strict async anchoring. Note how the sync anchor is applied consistently across all scenarios, helpers trigger only, and .reload bridges UI settlement with database truth.

```ruby
# spec/system/carts_spec.rb

RSpec.describe "Carts management", type: :system do
  describe "Adding a product to the cart" do
    let!(:product_A) { create(:product, name: "First Product", quantity: 2) }
    let!(:product_B) { create(:product, name: "Second Product", quantity: 2) }

    context "as an anonymous user" do
      context "who has no cart" do
        context "when there is enough stock" do
          scenario "creates a new cart and adds the product" do
            expect do
              add_to_cart product_A
              expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
            end.to change(Cart, :count).by(1).and change(LineItem, :count).by(1)

            cart = Cart.last
            expect(cart.products).to include(product_A)
          end
        end

        context "when there is not enough stock" do
          let!(:product_A) { create(:product, name: "First product", quantity: 0) }

          scenario "displays an error message" do
            expect do
              add_to_cart product_A
              expect(page.get_by_role("status").get_by_text("Sorry, there is not enough stock of #{product_A.name} to add more")).to be_visible
            end.to not_change(Cart, :count).and not_change(LineItem, :count)
          end
        end
      end

      context "who has a cart" do
        let!(:cart) do
          add_to_cart product_A
          expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
          Cart.last
        end
        let(:item_A) { cart.line_items.find_by(product: product_A) }

        context "when there is enough stock" do
          scenario "adds the product to the cart" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
            end.to change(LineItem, :count).by(1).and not_change(Cart, :count)

            expect(cart.products).to include(product_A, product_B)
          end

          context "with the same product already in" do
            scenario "increases the quantity of the item by one" do
              expect do
                add_to_cart product_A
                expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
              end.to change { item_A.reload.quantity }.by(1).and not_change(LineItem, :count)
            end
          end
        end

        context "when there is not enough stock" do
          let!(:product_B) { create(:product, name: "Second Product", quantity: 0) }

          scenario "displays an error message" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("status").get_by_text("Sorry, there is not enough stock of #{product_B.name} to add more")).to be_visible
            end.to not_change(Cart, :count).and not_change(LineItem, :count)
          end
        end
      end
    end

    context "as a logged-in user" do
      let!(:user) { create(:user) }
      before { login_as user }

      context "who has no cart" do
        context "when there is enough stock" do
          scenario "creates a new cart for the user and adds the product" do
            expect do
              add_to_cart product_A
              expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
            end.to change { user.reload.cart }.from(nil).to(an_instance_of(Cart)).and change(LineItem, :count).by(1)

            expect(user.reload.cart.products).to include(product_A)
          end
        end

        context "when there is not enough stock" do
          let!(:product_A) { create(:product, name: "First Product", quantity: 0) }

          scenario "displays an error message" do
            expect do
              add_to_cart product_A
              expect(page.get_by_role("status").get_by_text("Sorry, there is not enough stock of #{product_A.name} to add more")).to be_visible
            end.to not_change(Cart, :count).and not_change(LineItem, :count)
          end
        end
      end

      context "who has a cart" do
        before do
          add_to_cart product_A
          expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
        end
        let(:item_A) { user.cart.line_items.find_by(product: product_A) }

        context "when there is enough stock" do
          scenario "adds the product" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
            end.to change(LineItem, :count).by(1).and not_change(Cart, :count)

            expect(user.reload.cart.products).to include(product_A, product_B)
          end

          context "with the same product already in" do
            scenario "increases the quantity of the item by one" do
              expect do
                add_to_cart product_A
                expect(page.get_by_role("status").get_by_text("Product was added to your cart successfully")).to be_visible
              end.to change { item_A.reload.quantity }.by(1).and not_change(LineItem, :count)
            end
          end
        end

        context "when there is not enough stock" do
          let!(:product_B) { create(:product, name: "Second Product", quantity: 0) }

          scenario "displays an error message" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("status").get_by_text("Sorry, there is not enough stock of #{product_B.name} to add more")).to be_visible
            end.to not_change(Cart, :count).and not_change(LineItem, :count)
          end
        end
      end
    end
  end
end
```

### Why this structure works
* **Contextual repetition enforces behavioral isolation.** Anonymous and authenticated carts follow different domain contracts. Each context contains its own explicit proof so failures diagnose instantly without tracing shared setup or hidden state. Repetition here isn’t duplication—it’s parallel specification for isolated intent.
* **Single-pattern discipline enforces deterministic proof.** Helpers trigger only. All asynchronous settlement lives inside the spec’s `expect { }` block, eliminating conditional assumptions and keeping every scenario self-contained. The sync anchor is the sole mechanism; no configuration drift or hidden logic can obscure it.
* **Purpose dictates proof.** Commands verify mutations (`change`) or safe rejections (`not_change`). Queries verify visible communication. The specification documents exactly what the system does, not how it renders. Every assertion is a pre-established contract; implementation exists solely to fulfill it.

### The Final Step: Refactoring

Once the evidence is **Green**, we fulfill the cycle's final command: **Refactor (Step d).**

Refactoring is not about shrinking code; it is about clarifying responsibility. We enforce strict boundaries between the Web protocol and the Business Domain.

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

*   **`bundle exec guard`**: Instant feedback loop. Runs related specs on file save.
*   **Screenshot on Failure**: System test failures automatically save a full-page screenshot to `tmp/playwright_screenshots`.

---

**Storm is coming. Stay in the flow. ⛈️**

## License
MIT