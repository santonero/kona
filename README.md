<p align="center">
  <img src=".github/assets/kona_sloth.png" alt="Kona Sloth Mascot" width="300" height="300">
</p>

<h1 align="center">⛈️ Kona</h1>
<p align="center">
  <b>Design by Behavior.</b> A BDD Workflow for Ruby on Rails.
</p>

**Kona** elevates the BDD cycle into a rigorous standard for provable design. It establishes an environment where **Intent** dictates implementation, demanding every behavior be deterministic and fully isolated.

## ⚙️ Bootstrap

Initialize the environment:
```bash
rails new my_app -m https://raw.githubusercontent.com/santonero/kona/main/kona.rb
```

Enter your project and install system dependencies (one-time setup):
```bash
cd my_app && sudo ./node_modules/.bin/playwright install-deps
```

## 🧱 The Stack

*   **[Playwright](https://playwright.dev/):** Replaces Selenium. Semantic locators read human intent, not brittle CSS.
*   **[RSpec](https://rspec.info/) & FactoryBot:** Configured for documentary output and concise state injection.
*   **[Guard](https://github.com/guard/guard):** Instant, architecture-mapped feedback loop on file save.
*   **Hybrid Driver:** Capybara boots the server; Playwright controls the browser.

---

## ☁️ The Doctrine

Kona is the technical enforcement of the **[Designing by Behavior](DESIGNING_BY_BEHAVIOR.md)** manifesto. Its foundation rests on four unyielding steps:

🧭 **1. Determine** the next most important behavior.<br>
🔴 **2. Red:** Describe it with an example and watch it fail.<br>
🟢 **3. Green:** Write the simplest code to make the example pass.<br>
🛠️ **4. Refactor:** Improve the design without altering behavior.

---

## 🌩️ The Workflow in Action

Specifications are contracts. They must map your domain through this exact behavioral hierarchy:

```text
Domain (RSpec.describe)
└── Capacity (describe)
    └── Situation (context)
        └── Example (scenario / it)
```

### The Mutational Sync Anchor

[Commands](DESIGNING_BY_BEHAVIOR.md) trigger asynchronous state mutations. To guarantee the mutation has settled before verifying the database, we anchor the test to a visual confirmation. **Nest the UI expectation INSIDE the `expect { }` block.**

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
          # 1. TRIGGER
          page.get_by_role("button", name: "Create Product").click

          # 2. SYNC ANCHOR
          expect(page.get_by_role("heading", name: "A Nice Name")).to be_visible
        end.to change(Product, :count).by(1) # 3. STATE LOCK

        # 4. VISIBLE PROOF
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

          # 2. SYNC ANCHOR
          expect(page.get_by_text("Name can't be blank")).to be_visible
        end.not_to change(Product, :count) # 3. STATE LOCK

        # 4. VISIBLE PROOF
        expect(page.get_by_label("Name")).to have_value("")
        expect(page.get_by_label("Quantity")).to have_value("10")
      end
    end
  end
end
```

### The Canonical Workflow
This specification proves that the doctrine scales to complex realities.

*   **Absolute Isolation:** Anonymous and authenticated states follow distinct contracts. Repetition here is parallel specification. Explicit setup guarantees instant diagnosis.
*   **Deterministic Proof:** There are no async race conditions. The visual settlement anchors the **`expect { }`** block, eradicating flaky tests by design.
*   **Purpose Dictates Proof:** [Commands](DESIGNING_BY_BEHAVIOR.md) verify state mutations. [Queries](DESIGNING_BY_BEHAVIOR.md) verify visible outcomes. Every assertion demands irrefutable evidence.

```ruby
# spec/system/carts_spec.rb

RSpec.describe "Carts management", type: :system do
  describe "Adding a product to the cart" do
    let!(:product_A) { create(:product, name: "First Product", quantity: 2) }
    let(:product_B) { create(:product, name: "Second Product", quantity: 2) }

    context "as an anonymous user" do
      context "who has no cart" do
        context "when there is enough stock" do
          scenario "creates a new cart and adds the product" do
            expect do
              add_to_cart product_A
              expect(page.get_by_role("status").get_by_text("#{product_A.name} was added to your cart.")).to be_visible
            end.to change(Cart, :count).by(1).and change(LineItem, :count).by(1)

            cart = Cart.last
            expect(cart.products).to include(product_A)
          end
        end

        context "when the product is out of stock" do
          before { product_A.update!(quantity: 0) }

          scenario "rejects the addition and warns the user" do
            expect do
              add_to_cart product_A
              expect(page.get_by_role("alert").get_by_text("Sorry, you cannot add more of #{product_A.name} due to stock limits.")).to be_visible
            end.to not_change(Cart, :count).and not_change(LineItem, :count)
          end
        end
      end

      context "who has a cart" do
        before do
          add_to_cart product_A
          expect(page.get_by_role("status").get_by_text("#{product_A.name} was added to your cart.")).to be_visible
        end
        let(:cart) { Cart.last }
        let(:item_A) { cart.line_items.find_by(product: product_A) }

        context "when there is enough stock" do
          scenario "adds the product" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("status").get_by_text("#{product_B.name} was added to your cart.")).to be_visible
            end.to change(LineItem, :count).by(1)

            expect(cart.products).to include(product_A, product_B)
          end

          context "when the product is already in the cart" do
            scenario "increases the quantity of the item by one" do
              expect do
                page.get_by_role("button", name: "Add to Cart").click
                expect(page.get_by_role("status").get_by_text("#{product_A.name} was added to your cart.")).to be_visible
              end.to change { item_A.reload.quantity }.by(1).and not_change(LineItem, :count)
            end
          end
        end

        context "when the product is out of stock" do
          before { product_B.update!(quantity: 0) }

          scenario "rejects the addition and warns the user" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("alert").get_by_text("Sorry, you cannot add more of #{product_B.name} due to stock limits.")).to be_visible
            end.not_to change(LineItem, :count)
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
              expect(page.get_by_role("status").get_by_text("#{product_A.name} was added to your cart.")).to be_visible
            end.to change { user.reload.cart }.from(nil).to(an_instance_of(Cart)).and change(LineItem, :count).by(1)

            expect(user.reload.cart.products).to include(product_A)
          end
        end

        context "when the product is out of stock" do
          before { product_A.update!(quantity: 0) }

          scenario "rejects the addition and warns the user" do
            expect do
              add_to_cart product_A
              expect(page.get_by_role("alert").get_by_text("Sorry, you cannot add more of #{product_A.name} due to stock limits.")).to be_visible
            end.to not_change(Cart, :count).and not_change(LineItem, :count)
          end
        end
      end

      context "who has a cart" do
        before do
          add_to_cart product_A
          expect(page.get_by_role("status").get_by_text("#{product_A.name} was added to your cart.")).to be_visible
        end
        let(:item_A) { user.cart.line_items.find_by(product: product_A) }

        context "when there is enough stock" do
          scenario "adds the product" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("status").get_by_text("#{product_B.name} was added to your cart.")).to be_visible
            end.to change(LineItem, :count).by(1)

            expect(user.reload.cart.products).to include(product_A, product_B)
          end

          context "when the product is already in the cart" do
            scenario "increases the quantity of the item by one" do
              expect do
                page.get_by_role("button", name: "Add to Cart").click
                expect(page.get_by_role("status").get_by_text("#{product_A.name} was added to your cart.")).to be_visible
              end.to change { item_A.reload.quantity }.by(1).and not_change(LineItem, :count)
            end
          end
        end

        context "when the product is out of stock" do
          before { product_B.update!(quantity: 0) }

          scenario "rejects the addition and warns the user" do
            expect do
              add_to_cart product_B
              expect(page.get_by_role("alert").get_by_text("Sorry, you cannot add more of #{product_B.name} due to stock limits.")).to be_visible
            end.not_to change(LineItem, :count)
          end
        end
      end
    end
  end
end
```

---

## 📡 Developer Experience

**Continuous Feedback**
```bash
bundle exec guard
```

**Live DOM Inspection**

Prefix with `BROWSER=1` and drop `page.pause` in the spec to freeze execution and launch the Playwright inspector.
```bash
BROWSER=1 bundle exec rspec spec/system/carts_spec.rb
```

**Visual Evidence**

System test failures automatically save a full-page screenshot to `tmp/playwright_screenshots/`.

---

<p align="center">
<b>Storm is coming. Stay in the flow. 🦥⛈️</b>
</p>
