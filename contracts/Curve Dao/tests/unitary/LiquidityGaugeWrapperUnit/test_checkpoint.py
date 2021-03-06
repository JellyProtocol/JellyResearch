import pytest

YEAR = 86400 * 365


@pytest.fixture(scope="module", autouse=True)
def setup(accounts, gauge_controller, minter, liquidity_gauge, token):
    token.set_minter(minter, {"from": accounts[0]})

    gauge_controller.add_type(b"Liquidity", 10 ** 10, {"from": accounts[0]})
    gauge_controller.add_gauge(liquidity_gauge, 0, 0, {"from": accounts[0]})


def test_user_checkpoint(accounts, unit_gauge):
    unit_gauge.user_checkpoint(accounts[1], {"from": accounts[1]})


def test_user_checkpoint_new_period(accounts, chain, unit_gauge):
    unit_gauge.user_checkpoint(accounts[1], {"from": accounts[1]})
    chain.sleep(int(YEAR * 1.1))
    unit_gauge.user_checkpoint(accounts[1], {"from": accounts[1]})


def test_user_checkpoint_wrong_account(accounts, unit_gauge):
    # this is allowed, because anyone can also transfer tokens to trigger
    unit_gauge.user_checkpoint(accounts[2], {"from": accounts[1]})
