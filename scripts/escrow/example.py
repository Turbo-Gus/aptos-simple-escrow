import os
from time import sleep
from coin import CoinClient

from url_tool import explorer
from escrow_sdk import EscrowClient
from sdk.account import Account
from sdk.client import FaucetClient, RestClient

from config import BASE_ACCOUNT, PRIVATE_KEY_STRING, DEVNET_URL, FAUCET_URL

superadmin = Account.load_key(PRIVATE_KEY_STRING)

baseclient = RestClient(DEVNET_URL)
faucet_client = FaucetClient(FAUCET_URL, baseclient)

bob = Account.generate()
alice = Account.generate()
print(f"Superadmin account: {superadmin.address()}")
print(f"Bob account: {bob.address()}")
print(f"Alice account: {alice.address()}")

print("fund admin")
faucet_client.fund_account(superadmin.address(), 1_000_000)
print("fund bob")
faucet_client.fund_account(bob.address(), 1_000_000)
print("fund alice")
faucet_client.fund_account(alice.address(), 1_000_000)

coin_client = CoinClient(DEVNET_URL)
client = EscrowClient(DEVNET_URL, superadmin.address().hex() + "::Escrow")

# print("Init ACoin")
# init_a_tx = coin_client.initialize_coin(superadmin, "A")
# print(explorer(init_a_tx))
# client.wait_for_transaction(init_a_tx)

# print("Init BCoin")
# init_b_tx = coin_client.initialize_coin(superadmin, "B")
# print(explorer(init_b_tx))
# client.wait_for_transaction(init_b_tx)


# ACoin, BCoin, or CCoin
print("Registering ACoin for Alice")
alice_a_reg = coin_client.register_coin(superadmin.address().hex(), alice, "A")
print(explorer(alice_a_reg))
client.wait_for_transaction(alice_a_reg)

print("Registering BCoin for Bob")
bob_b_reg = coin_client.register_coin(superadmin.address().hex(), bob, "B")
print(explorer(bob_b_reg))
client.wait_for_transaction(bob_b_reg)


print("Minting ACoin to Alice")
mint_a_tx = coin_client.mint_coin(superadmin, alice.address(), "A", 5_000_000)
print(explorer(mint_a_tx))
coin_client.wait_for_transaction(mint_a_tx)

print("Minting BCoin to Bob")
mint_b_tx = coin_client.mint_coin(superadmin, bob.address(), "B", 6_000_000)
print(explorer(mint_b_tx))
coin_client.wait_for_transaction(mint_b_tx)

print("Bob's balance: ", coin_client.get_balance(
    superadmin.address(), bob.address(), "B"))

print("Alice's balance: ", coin_client.get_balance(
    superadmin.address(), alice.address(), "A"))


print("Creating Alice's escrow")
init_e_hash = client.init_escrow(alice)
print(explorer(init_e_hash))
client.wait_for_transaction(init_e_hash)

print("Alice's balance: ", coin_client.get_balance(
    superadmin.address(), alice.address(), "A"))

print("Add Alice's offer")
offer_hash = client.add_offer(alice, "A", "B", 1, 5)
print(explorer(offer_hash))
client.wait_for_transaction(offer_hash)

print("Alice's balance: ", coin_client.get_balance(
    superadmin.address(), alice.address(), "A"))

print("Bob Takes Alice's offer")
take_hash = client.take_offer(bob, alice.address(), "A", "B")
print(explorer(offer_hash))
client.wait_for_transaction(take_hash)


print("Alice's A: ", coin_client.get_balance(
    superadmin.address(), alice.address(), "A"))

print("Alice's B: ", coin_client.get_balance(
    superadmin.address(), alice.address(), "B"))

print("Bob's A: ", coin_client.get_balance(
    superadmin.address(), bob.address(), "A"))

print("Bobs's B: ", coin_client.get_balance(
    superadmin.address(), bob.address(), "B"))


# Alice makes another offer
print("Add Alice's 2nd offer")
offer_2_hash = client.add_offer(alice, "A", "B", 4_312_345, 1)
print(explorer(offer_2_hash))
client.wait_for_transaction(offer_2_hash)

print("Alice's A: ", coin_client.get_balance(
    superadmin.address(), alice.address(), "A"))

print("Alice cancels offer")
cancel_hash = client.cancel_offer(alice, "A", "B")
print(explorer(cancel_hash))
client.wait_for_transaction(cancel_hash)

print("Alice's A: ", coin_client.get_balance(
    superadmin.address(), alice.address(), "A"))
