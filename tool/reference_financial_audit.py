"""Executable reference-model audit independent of Flutter SDK.
This is not a substitute for Dart repository tests; it validates the financial contract itself.
"""
from dataclasses import dataclass

@dataclass
class Account:
    kind: str  # asset/liability
    balance: int = 0

class Model:
    def __init__(self):
        self.accounts = {}
        self.expense = 0
        self.income = 0
    def add(self, name, kind, opening=0): self.accounts[name] = Account(kind, opening)
    def nw(self): return sum(a.balance if a.kind == 'asset' else -a.balance for a in self.accounts.values())
    def expense_tx(self, account, amount):
        a=self.accounts[account]; a.balance += -amount if a.kind=='asset' else amount; self.expense += amount
    def income_tx(self, account, amount): self.accounts[account].balance += amount; self.income += amount
    def transfer(self, src,dst,amount,fee=0): self.accounts[src].balance-=amount+fee; self.accounts[dst].balance+=amount; self.expense+=fee
    def refund(self, account, amount):
        a=self.accounts[account]; a.balance += amount if a.kind=='asset' else -amount; self.expense-=amount
    def cc_pay(self, src,card,amount): self.accounts[src].balance-=amount; self.accounts[card].balance-=amount
    def loan_draw(self,asset,loan,amount): self.accounts[asset].balance+=amount; self.accounts[loan].balance+=amount
    def loan_pay(self,asset,loan,principal,interest,fee):
        self.accounts[asset].balance-=principal+interest+fee; self.accounts[loan].balance-=principal; self.expense+=interest+fee

def run():
    m=Model(); m.add('bank','asset',1_000_000); m.add('wallet','asset',0)
    before=m.nw(); m.transfer('bank','wallet',500_000,1_000)
    assert m.nw()==before-1_000 and m.expense==1_000

    m2=Model(); m2.add('bank','asset',1_000_000); m2.add('card','liability',0)
    m2.expense_tx('card',300_000); nw=m2.nw(); m2.cc_pay('bank','card',300_000)
    assert m2.nw()==nw and m2.expense==300_000 and m2.accounts['card'].balance==0

    m3=Model(); m3.add('bank','asset',500_000); m3.add('loan','liability',0)
    nw=m3.nw(); m3.loan_draw('bank','loan',1_000_000); assert m3.nw()==nw and m3.income==0
    m3.loan_pay('bank','loan',100_000,10_000,5_000); assert m3.nw()==nw-15_000 and m3.expense==15_000

    m4=Model(); m4.add('bank','asset',500_000); m4.expense_tx('bank',200_000); m4.refund('bank',50_000)
    assert m4.accounts['bank'].balance==350_000 and m4.expense==150_000
    print('PASS: reference financial contract')

if __name__ == '__main__': run()
