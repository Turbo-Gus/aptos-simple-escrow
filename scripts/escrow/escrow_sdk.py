from typing import Optional
from sdk.account_address import AccountAddress
from sdk.account import Account
from sdk.client import RestClient
from sdk.bcs import Serializer
from sdk.transactions import (
    EntryFunction,
    TransactionArgument,
    TransactionPayload,
)
from sdk.type_tag import StructTag, TypeTag

from config import BASE_ACCOUNT


class EscrowClient(RestClient):
    def __init__(self, url: str, module_address: str):
        self.module_address = module_address

        super().__init__(url)

    def init_escrow(self, account: Account) -> str:
        """Allows the account to create escrow offers"""

        payload = EntryFunction.natural(
            self.module_address,
            "init_escrow",
            [],
            [],
        )
        signed_transaction = self.create_single_signer_bcs_transaction(
            account, TransactionPayload(payload)
        )
        return self.submit_bcs_transaction(signed_transaction)

    def add_offer(self, signer: Account, pay_coin: str, receive_coin: str,  pay_amount: int, receive_amount: int) -> str:
        """Creates an escrow offer that anyone can take"""
        payload = EntryFunction.natural(
            self.module_address,
            "add_offer",
            # IDK a better way to get the coins, but there has to be one
            [
                TypeTag(StructTag.from_str(
                    f"{BASE_ACCOUNT}::test_coins::{pay_coin}Coin")),
                TypeTag(StructTag.from_str(
                    f"{BASE_ACCOUNT}::test_coins::{receive_coin}Coin")),
            ],
            [
                TransactionArgument(pay_amount, Serializer.u64),
                TransactionArgument(receive_amount, Serializer.u64),
            ],
        )
        signed_transaction = self.create_single_signer_bcs_transaction(
            signer, TransactionPayload(payload)
        )
        return self.submit_bcs_transaction(signed_transaction)

    def cancel_offer(self, signer: Account, pay_coin: str, receive_coin: str) -> str:
        """Creates an escrow offer that anyone can take"""
        payload = EntryFunction.natural(
            self.module_address,
            "cancel_offer",
            # IDK a better way to get the coins, but there has to be one
            [
                TypeTag(StructTag.from_str(
                    f"{BASE_ACCOUNT}::test_coins::{pay_coin}Coin")),
                TypeTag(StructTag.from_str(
                    f"{BASE_ACCOUNT}::test_coins::{receive_coin}Coin")),
            ],
            [],
        )
        signed_transaction = self.create_single_signer_bcs_transaction(
            signer, TransactionPayload(payload)
        )
        return self.submit_bcs_transaction(signed_transaction)

    def take_offer(self, signer: Account, initiator: AccountAddress, pay_coin: str, receive_coin: str) -> str:
        """Take an escrow offer"""
        payload = EntryFunction.natural(
            self.module_address,
            "take_offer",
            # IDK a better way to get the coins, but there has to be one
            [
                TypeTag(StructTag.from_str(
                    f"{BASE_ACCOUNT}::test_coins::{pay_coin}Coin")),
                TypeTag(StructTag.from_str(
                    f"{BASE_ACCOUNT}::test_coins::{receive_coin}Coin")),
            ],
            [TransactionArgument(initiator, Serializer.struct)],
        )
        signed_transaction = self.create_single_signer_bcs_transaction(
            signer, TransactionPayload(payload)
        )
        return self.submit_bcs_transaction(signed_transaction)
