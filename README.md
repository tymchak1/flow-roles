Flow Roles

1. Roles contract
    On-chain roles that are granted for specific actions (3 roles)
    - programmatically, no managment by admin
        - you do smth -> get the role
        - you can get smth after acquiring the role (NFT, ETH, ) 
    - permanent and temporary roles
        - expires if you would not act in X way for Y amount of time
2. Protocol contract
    Simple vault with no interest (but puts all the money(ETH) to AAVE)
    - 6 month, 1 year, 5 years
    - just freeze money and become a part of community
    - can be added extra logic, where roles unlock some perks on platform (but this is just the base to create granting logic)

3 roles:
    - deposited  >1 ether for 5 years (role: *** + NFT -> gets 0.001 ether monthly)
    - deposited >3 times >1 ether (role -> gets 0.0005 ether monthly)
    - deposit >0.3 ether monthly (role -> gets 0.0005 ether monthly)
Granting roles programmatically:
   - Vault state changes -> Keeper -> Role Manager->checkAndGrantRole?