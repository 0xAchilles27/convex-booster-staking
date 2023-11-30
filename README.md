# Convex Booster Staking

This is a staking contract designed to enhance rewards through the Convex platform.

### Introducing Convex Finance

A platform built to boost rewards for CRV stakers and liquidity providers alike, all in a simple and easy to use interface. Convex aims to simplify staking on Curve, as well as the CRV-locking system with the help of its native fee-earning token: CVX.

If you’ve ever been a Curve LP, you know it is somewhat non-trivial to maximize your boost by depositing/maintaining your veCRV balance. If you’ve never been a Curve LP, it may be intimidating to do so without being a DeFi power user. Convex aims to make this process easy and bring the CRV boost ecosystem to everyone.

Liquidity providers earn trading fees and claim boosted CRV without locking CRV themselves.
Convex has no deposit or withdrawal fees, and a low performance fee, which is distributed to CRV stakers and CVX token holders.

### Overview

- Users can stake ETH, any whitelisted tokens, or specified Curve LP tokens using their respective deposit functions.
- For single tokens, they are converted into Curve LP tokens upon deposit, and the vault deposits them in the Convex Booster contract.
- The vault receives CRV rewards and the Convex native token(CVX) pro rata for each CRV from Convex platform.
- The vault distributes CRV and CVX rewards to users following the Synthetix staking mechanism.