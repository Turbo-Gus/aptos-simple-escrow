from typing import Optional

from sdk.account import Account
from sdk.account_address import AccountAddress
from sdk.bcs import Serializer
from sdk.client import FaucetClient, RestClient
from sdk.transactions import (
    EntryFunction,
    TransactionArgument,
    TransactionPayload,
)
from sdk.type_tag import StructTag, TypeTag


class CoinClient(RestClient):
    def initialize_coin(self, sender: Account, coin_type: str) -> Optional[str]:
        """Initialize a new coin with the given coin type."""

        payload = EntryFunction.natural(
            "0x1::managed_coin",
            "initialize",
            [TypeTag(StructTag.from_str(
                f"{sender.address()}::test_coins::{coin_type}Coin"))],
            [
                TransactionArgument(f"{coin_type}Coin", Serializer.str),
                TransactionArgument(f"{coin_type}", Serializer.str),
                TransactionArgument(6, Serializer.u8),
                TransactionArgument(False, Serializer.bool),
            ],
        )
        signed_transaction = self.create_single_signer_bcs_transaction(
            sender, TransactionPayload(payload)
        )
        return self.submit_bcs_transaction(signed_transaction)

    def register_coin(self, coin_address: AccountAddress, registree: Account, coin_type: str) -> str:
        """Register the receiver account to receive transfers for the new coin."""

        payload = EntryFunction.natural(
            "0x1::managed_coin",
            "register",
            [TypeTag(StructTag.from_str(
                f"{coin_address}::test_coins::{coin_type}Coin"))],
            [],
        )
        signed_transaction = self.create_single_signer_bcs_transaction(
            registree, TransactionPayload(payload)
        )
        return self.submit_bcs_transaction(signed_transaction)

    def mint_coin(
        self, minter: Account, receiver_address: AccountAddress, coin_type: str, amount: int
    ) -> str:
        """Register the receiver account to receive transfers for the new coin."""

        payload = EntryFunction.natural(
            "0x1::managed_coin",
            "mint",
            [TypeTag(StructTag.from_str(
                f"{minter.address()}::test_coins::{coin_type}Coin"))],
            [
                TransactionArgument(receiver_address, Serializer.struct),
                TransactionArgument(amount, Serializer.u64),
            ],
        )
        signed_transaction = self.create_single_signer_bcs_transaction(
            minter, TransactionPayload(payload)
        )
        return self.submit_bcs_transaction(signed_transaction)

    def get_balance(
        self,
        coin_address: AccountAddress,
        account_address: AccountAddress,
        coin_type: str,
    ) -> str:
        """Returns the coin balance of the given account"""

        balance = self.account_resource(
            account_address,
            f"0x1::coin::CoinStore<{coin_address}::test_coins::{coin_type}Coin>",
        )
        return balance["data"]["coin"]["value"]
