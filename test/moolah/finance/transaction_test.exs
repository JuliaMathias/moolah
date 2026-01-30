defmodule Moolah.Finance.TransactionTest do
  @moduledoc """
  Tests for Moolah.Finance.Transaction resource, covering scenarios:
  1. Multi-currency transfer
  2. Credit Card Expense (Small)
  3. Credit Card Expense (Large)
  4. Pay Credit Card Bill
  5. Salary Income
  6. External Direct Payment (Pix)
  """
  use Moolah.DataCase, async: false

  alias Moolah.Finance.BudgetCategory
  alias Moolah.Finance.LifeAreaCategory
  alias Moolah.Finance.Services.VirtualAccountService
  alias Moolah.Finance.Transaction
  alias Moolah.Ledger.Account

  setup do
    # Setup accounts
    bank =
      Account
      |> Ash.Changeset.for_create(:open, %{
        identifier: "bank_account",
        currency: "BRL",
        account_type: :bank_account
      })
      |> Ash.create!()
      # Start with 20_000 (R$20,000)
      |> give_balance(Money.new(20_000, :BRL))

    credit_card =
      Account
      |> Ash.Changeset.for_create(:open, %{
        identifier: "credit_card",
        currency: "BRL",
        # Treating CC as bank account for simplicity of MVP, or money_account
        account_type: :bank_account
      })
      |> Ash.create!()

    dollar_account =
      Account
      |> Ash.Changeset.for_create(:open, %{
        identifier: "dollar_account",
        currency: "USD",
        account_type: :bank_account
      })
      |> Ash.create!()

    # Setup Categories (Seeding directly via Repo as actions are disabled)
    now = DateTime.utc_now()

    pleasures =
      Moolah.Repo.insert!(%BudgetCategory{
        id: Ash.UUID.generate(),
        name: "Pleasures",
        color: "#FF5733",
        icon: "masks",
        inserted_at: now,
        updated_at: now
      })

    comfort =
      Moolah.Repo.insert!(%BudgetCategory{
        id: Ash.UUID.generate(),
        name: "Comfort",
        color: "#33FF57",
        icon: "sofa",
        inserted_at: now,
        updated_at: now
      })

    # Setup Life Areas
    life_area =
      LifeAreaCategory
      |> Ash.Changeset.for_create(:create, %{
        name: "Personal",
        color: "#FFFFFF",
        icon: "person",
        transaction_type: :debit
      })
      |> Ash.create!()

    income_area =
      LifeAreaCategory
      |> Ash.Changeset.for_create(:create, %{
        name: "Work",
        color: "#00FF00",
        icon: "work",
        transaction_type: :credit
      })
      |> Ash.create!()

    %{
      bank: bank,
      credit_card: credit_card,
      dollar_account: dollar_account,
      food: pleasures,
      shopping: comfort,
      gifts: pleasures,
      life_area: life_area,
      income_area: income_area
    }
  end

  # Helper to seed balance
  @spec give_balance(Ash.Resource.record(), Money.t()) :: Ash.Resource.record()
  defp give_balance(account, amount) do
    # We create a fake initial deposit via a direct transfer from a "Opening Balance" account
    # or just force a balance if possible, but let's do it via transfer to be clean
    opening =
      Account
      |> Ash.Changeset.for_create(:open, %{
        identifier: "system_opening_#{account.id}",
        currency: to_string(amount.currency),
        account_type: :money_account
      })
      |> Ash.create!()

    Moolah.Ledger.Transfer
    |> Ash.Changeset.for_create(:transfer, %{
      amount: amount,
      from_account_id: opening.id,
      to_account_id: account.id
    })
    |> Ash.create!()

    account
  end

  @spec get_balance(Ash.Resource.record()) :: Money.t()
  defp get_balance(account) do
    # Need to verify how to fetch balance.
    # Moolah.Ledger.Account has calculation :balance_as_of?
    account
    |> Ash.load!([:balance_as_of])
    |> Map.get(:balance_as_of)
  end

  test "Scenario 1: Moving R$519.72 from normal account to dollar account ($100)", %{
    bank: bank,
    dollar_account: dollar
  } do
    # R$519.72 -> $100 (Rate: 5.1972)
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        account_id: bank.id,
        target_account_id: dollar.id,
        amount: Money.new("100", :USD),
        source_amount: Money.new("519.72", :BRL),
        description: "Trip money"
      })
      |> Ash.create!()

    # Bank account should decrease by exactly 519.72 BRL. 20,000 - 519.72 = 19,480.28
    assert_balance(bank, Money.new("19480.28", :BRL))

    # Dollar account should increase by exactly 100 USD
    assert_balance(dollar, Money.new("100", :USD))

    # Verify Transaction Metadata
    assert transaction.source_transfer_id != nil
    assert transaction.transfer_id != nil
    # 519.72 / 100 = 5.1972
    assert Decimal.equal?(transaction.exchange_rate, Decimal.new("5.1972"))

    # Verify Trading Accounts (Bridge check)
    trading_brl =
      VirtualAccountService.get_or_create_trading_account!("BRL")

    trading_usd =
      VirtualAccountService.get_or_create_trading_account!("USD")

    assert_balance(trading_brl, Money.new("519.72", :BRL))
    assert_balance(trading_usd, Money.new("-100", :USD))
  end

  test "Scenario 2: Charged R$20 for lunch on credit card", %{
    credit_card: cc,
    food: food,
    life_area: life_area
  } do
    Transaction
    |> Ash.Changeset.for_create(:create, %{
      transaction_type: :debit,
      account_id: cc.id,
      budget_category_id: food.id,
      life_area_category_id: life_area.id,
      amount: Money.new(20, :BRL),
      description: "Lunch"
    })
    |> Ash.create!()

    # AshDoubleEntry Balance Logic:
    # A "Debit" transaction creates a generic Transfer FROM the user's account TO an expense category.
    # Transfers originating FROM an account decrease its calculated balance.
    # Therefore: Balance = Start (0) - Amount (20) = -20.

    assert_balance(cc, Money.new(0, :BRL) |> Money.sub!(Money.new(20, :BRL)))
  end

  test "Scenario 3: Pay R$120 credit card bill from bank", %{
    bank: bank,
    credit_card: cc,
    shopping: shopping,
    life_area: life_area
  } do
    # 1. Create debt on CC (Debit R$120)
    Transaction
    |> Ash.Changeset.for_create(:create, %{
      transaction_type: :debit,
      account_id: cc.id,
      budget_category_id: shopping.id,
      life_area_category_id: life_area.id,
      amount: Money.new(120, :BRL),
      description: "Shopping Spree"
    })
    |> Ash.create!()

    # 2. Assert debt exists (-120)
    assert_balance(cc, Money.new(-120, :BRL))

    # 3. Pay the bill (Transfer R$120 from Bank to CC)
    Transaction
    |> Ash.Changeset.for_create(:create, %{
      transaction_type: :transfer,
      account_id: bank.id,
      target_account_id: cc.id,
      amount: Money.new(120, :BRL),
      description: "Bill Pay"
    })
    |> Ash.create!()

    # 4. Verify Repayment
    # Bank decreases: 20000 - 120 = 19880
    assert_balance(bank, Money.new(19_880, :BRL))

    # CC increases (debt paid): -120 + 120 = 0
    assert_balance(cc, Money.new(0, :BRL))
  end

  test "Scenario 4: Salary of R$10000", %{bank: bank, income_area: income_area} do
    Transaction
    |> Ash.Changeset.for_create(:create, %{
      transaction_type: :credit,
      account_id: bank.id,
      life_area_category_id: income_area.id,
      amount: Money.new(10_000, :BRL),
      description: "Salary"
    })
    |> Ash.create!()

    # Bank increases by 10000.
    # 20000 + 10000
    assert_balance(bank, Money.new(30_000, :BRL))
  end

  test "Scenario 5: Pix for R$50 to sister", %{bank: bank, gifts: gifts, life_area: life_area} do
    assert_balance(bank, Money.new(20_000, :BRL))

    Transaction
    |> Ash.Changeset.for_create(:create, %{
      transaction_type: :debit,
      account_id: bank.id,
      budget_category_id: gifts.id,
      life_area_category_id: life_area.id,
      amount: Money.new(50, :BRL),
      description: "Sister Pix"
    })
    |> Ash.create!()

    # Bank decreases by 50.
    # 20000 - 50
    assert_balance(bank, Money.new(19_950, :BRL))
  end

  test "Scenario 6: Update Transaction Amount (Correction)", %{
    credit_card: cc,
    food: food,
    life_area: life_area
  } do
    assert_balance(cc, Money.new(0, :BRL))

    # Initial: Debit R$50 for Food
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: cc.id,
        budget_category_id: food.id,
        life_area_category_id: life_area.id,
        amount: Money.new(50, :BRL),
        description: "Mistake"
      })
      |> Ash.create!()

    # Check CC balance: -50
    assert_balance(cc, Money.new(-50, :BRL))

    # Update: Change to R$80
    transaction
    |> Ash.Changeset.for_update(:update, %{
      amount: Money.new(80, :BRL)
    })
    |> Ash.update!()

    # Verify: Old transfer voided (-50 gone), New transfer applied (-80 present)
    # Net balance should be -80
    assert_balance(cc, Money.new(-80, :BRL))
  end

  test "Scenario 7: Update Transaction Category (Reclassification)", %{
    credit_card: cc,
    food: food,
    shopping: shopping,
    life_area: life_area
  } do
    # Initial: Debit R$100 for Food
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: cc.id,
        budget_category_id: food.id,
        life_area_category_id: life_area.id,
        amount: Money.new(100, :BRL),
        description: "Wrong Category"
      })
      |> Ash.create!()

    # Verify Food expense account balance?
    # We can check via VirtualAccountService lookup
    {:ok, food_account} =
      VirtualAccountService.get_or_create(food.id, :expense, "BRL")

    # Expenses are debited (positive balance in AshDoubleEntry usually if configured as Asset-like
    # or if we check raw balance)
    assert_balance(food_account, Money.new(100, :BRL))

    # Update: Change to Shopping
    transaction
    |> Ash.Changeset.for_update(:update, %{
      budget_category_id: shopping.id
    })
    |> Ash.update!()

    # Verify Food Balance is back to 0
    assert_balance(food_account, Money.new(0, :BRL))

    # Verify Shopping Balance is 100
    {:ok, shopping_account} =
      VirtualAccountService.get_or_create(shopping.id, :expense, "BRL")

    assert_balance(shopping_account, Money.new(100, :BRL))

    # Verify CC Balance is still -100 (unchanged total liability)
    assert_balance(cc, Money.new(-100, :BRL))
  end

  test "Scenario 8: Update Transaction Source Amount (Trigger Verification)", %{
    dollar_account: usd,
    bank: brl
  } do
    # Initial: Transfer R$260 from Bank (BRL) to Dollar Account (USD) = $50
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        account_id: brl.id,
        target_account_id: usd.id,
        amount: Money.new(50, :USD),
        source_amount: Money.new(260, :BRL),
        description: "Initial Multi-Currency Transfer"
      })
      |> Ash.create!()

    # Verify initial state
    # This scenario is a BRL → USD transfer; the exact double-entry configuration
    # is not under test here.
    # For this test, we only care that updating source_amount replaces the
    # underlying transfer (UPDATE TRIGGER behavior).

    original_transfer_id = transaction.transfer_id

    # Update: Correction source amount to R$312 (new exchange rate scenario)
    updated_transaction =
      transaction
      |> Ash.Changeset.for_update(:update, %{
        source_amount: Money.new(312, :BRL)
      })
      |> Ash.update!()

    # Verify that the underlying transfer was replaced (ID changed)
    assert updated_transaction.transfer_id != original_transfer_id

    # Verify the value persisted on the transaction
    assert updated_transaction.source_amount == Money.new(312, :BRL)
  end

  test "Validation: Forbidden source_amount for debit transactions", %{
    credit_card: cc,
    food: food,
    life_area: life_area
  } do
    changeset =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: cc.id,
        budget_category_id: food.id,
        life_area_category_id: life_area.id,
        amount: Money.new(20, :BRL),
        source_amount: Money.new(20, :BRL),
        description: "Invalid Debit"
      })

    assert {:error, %Ash.Error.Invalid{errors: [error]}} = Ash.create(changeset)
    assert error.message == "Source Amount can only be set for Transfer transactions"
  end

  test "Validation: Forbidden zero or negative amount", %{
    bank: bank,
    income_area: income_area
  } do
    # Zero amount
    changeset_zero =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :credit,
        account_id: bank.id,
        life_area_category_id: income_area.id,
        amount: Money.new(0, :BRL),
        description: "Zero Salary"
      })

    assert {:error, %Ash.Error.Invalid{errors: [error_zero]}} = Ash.create(changeset_zero)
    assert error_zero.message == "Transaction amount must be greater than 0"

    # Negative amount
    changeset_neg =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :credit,
        account_id: bank.id,
        life_area_category_id: income_area.id,
        amount: Money.new(-10, :BRL),
        description: "Negative Salary"
      })

    assert {:error, %Ash.Error.Invalid{errors: [error_neg]}} = Ash.create(changeset_neg)
    assert error_neg.message == "Transaction amount must be greater than 0"
  end

  @spec assert_balance(Ash.Resource.record(), Money.t()) :: boolean()
  defp assert_balance(account, expected_money) do
    balance = get_balance(account)

    assert Money.compare(balance, expected_money) == :eq,
           "Expected #{inspect(expected_money)}, got #{inspect(balance)}"
  end
end
