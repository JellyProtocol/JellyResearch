import pytest

from tests.conftest import approx

REWARD = 10 ** 20
WEEK = 7 * 86400
LP_AMOUNT = 10 ** 18


@pytest.fixture(scope="module", autouse=True)
def initial_setup(accounts, coin_reward, reward_contract, mock_lp_token, liquidity_gauge_reward):
    # Fund
    coin_reward._mint_for_testing(accounts[0], REWARD)
    coin_reward.transfer(reward_contract, REWARD, {"from": accounts[0]})
    reward_contract.notifyRewardAmount(REWARD, {"from": accounts[0]})

    # Deposit
    mock_lp_token.transfer(accounts[1], LP_AMOUNT, {"from": accounts[0]})
    mock_lp_token.approve(liquidity_gauge_reward, LP_AMOUNT, {"from": accounts[1]})
    liquidity_gauge_reward.deposit(LP_AMOUNT, {"from": accounts[1]})


def test_claim_one_lp(accounts, chain, liquidity_gauge_reward, coin_reward):
    chain.sleep(WEEK)

    liquidity_gauge_reward.withdraw(LP_AMOUNT, {"from": accounts[1]})
    liquidity_gauge_reward.claim_rewards({"from": accounts[1]})

    reward = coin_reward.balanceOf(accounts[1])
    assert reward <= REWARD
    assert approx(REWARD, reward, 1.001 / WEEK)  # ganache-cli jitter of 1 s


def test_claim_for_other(accounts, chain, liquidity_gauge_reward, coin_reward):
    chain.sleep(WEEK)

    liquidity_gauge_reward.withdraw(LP_AMOUNT, {"from": accounts[1]})
    liquidity_gauge_reward.claim_rewards(accounts[1], {"from": accounts[2]})

    assert coin_reward.balanceOf(accounts[2]) == 0

    reward = coin_reward.balanceOf(accounts[1])
    assert reward <= REWARD
    assert approx(REWARD, reward, 1.001 / WEEK)  # ganache-cli jitter of 1 s


def test_claim_for_other_no_reward(accounts, chain, liquidity_gauge_reward, coin_reward):
    chain.sleep(WEEK)

    liquidity_gauge_reward.withdraw(LP_AMOUNT, {"from": accounts[1]})
    liquidity_gauge_reward.claim_rewards(accounts[2], {"from": accounts[1]})

    assert coin_reward.balanceOf(accounts[1]) == 0
    assert coin_reward.balanceOf(accounts[2]) == 0


def test_claim_two_lp(
    accounts, chain, liquidity_gauge_reward, mock_lp_token, coin_reward, no_call_coverage
):

    # Deposit
    mock_lp_token.approve(liquidity_gauge_reward, LP_AMOUNT, {"from": accounts[0]})
    liquidity_gauge_reward.deposit(LP_AMOUNT, {"from": accounts[0]})

    chain.sleep(WEEK)

    # Claim rewards
    rewards = []
    for i in range(2):
        liquidity_gauge_reward.claim_rewards({"from": accounts[i]})
        rewards += [coin_reward.balanceOf(accounts[i])]

    # Calculate rewards
    claimable_rewards = [
        liquidity_gauge_reward.claimable_reward(acc, {"from": acc}) for acc in accounts[:2]
    ]

    # Calculation == results
    assert tuple(claimable_rewards) == tuple(rewards)

    # Approximately equal apart from what caused by 1 s ganache-cli jitter
    assert sum(rewards) <= REWARD
    assert approx(sum(rewards), REWARD, 1.001 / WEEK)  # ganache-cli jitter of 1 s
    assert approx(rewards[0], rewards[1], 2.002 * WEEK)
