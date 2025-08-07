# CROSS-CHAIN-REBASE-TOKEN

1. A protocol that allows users to deposit inside a vault and in return gain rebase token to represent their underlying asset.


2. Rebase Token -> balanceOf function is dynamic to show the changing balance with time.
   - Balance increases linearly/slowly over time.
   - Mint token to our users everytime they perform an action(minting , burning, transfering, bridging, etc).


3. Intrest Rate
   - Individually set an intrest rate for user based on global intrestRate of the protocol at the time user deposits into a vault.
   - This global rewards can only decrease to reward early adopters.
   - Increase Token Adoption.