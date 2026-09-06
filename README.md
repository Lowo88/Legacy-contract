# Legacy Contract — Ironwood time vault + Crosslink staking check-in

On-chain **policy** for a Zcash Ironwood note that may be staked to a Crosslink finalizer. MIT. **Not audited.**

The contract **does not move ZEC**. It records the lock, the finalizer, check-ins, and whether a 10% early-exit penalty is owed to the donation wallet. Unstake / send is done by the wallet / Crosslink node that watches the events.

## Rules

| Rule | Behavior |
|------|----------|
| Asset | Ironwood **note commitment** (`bytes32`). No LGC. |
| Max lock | **30 years** (`MAX_LOCK`) |
| Min lock | **30 days** (`MIN_LOCK`) |
| Check-in | **Only while staked** to a Crosslink finalizer. Owner or **manager** pings every **30 days** that the finalizer meets standard. |
| Missed check-in | `recallFromFinalizer`: unstake from the finalizer, **stay in the vault** until the original `unlockAt`. No heir payout. No 10% fee. |
| Restake | Owner/manager may `restakeToFinalizer` to the same or a new finalizer before unlock. |
| Scheduled release | After `unlockAt`, `markReleased` — **0%** penalty. |
| Early release | Before `unlockAt`, `earlyRelease` — **10%** (`1000` bps) attested to the **Ironwood donation UA** (`donationUa` / `donationUaHash`). Heirs get the remaining 90% off-chain. |

## Roles

- **Owner** — creates the vault, check-in, restake, early/scheduled release
- **Manager** — same staking ops as owner (watch the finalizer)
- **Trustee** — can `recallFromFinalizer` if check-in is late; can `markReleased` after unlock
- **Donation UA** — Ironwood unified address (`u1…` / `utest1…`) set at deploy; early-exit 10% destination. **Not** an ETH `0x` address.

## Setup

```bash
npm install
npx hardhat test
```

Deploy (Ironwood donation UA only):

```bash
set DONATION_UA=u1…
npx hardhat run scripts/deploy.ts --network localhost
```

## Create a vault

```js
const heirHash = await vault.hashUnifiedAddress("u1heir…");
await vault.createVault(
  noteCommitment,   // Ironwood cmx
  30 * 365 * 86400, // lock: 30 days min, 30 years max
  finalizer,        // 32-byte Crosslink finalizer id
  managerAddress,
  [heirHash],
  [trusteeAddress],
  "legacy message"
);
```

## Security / honesty

- Registering a commitment on Ethereum links that note to this policy.
- `RecalledFromFinalizer` / `VaultReleased` do **not** unbond on Crosslink by themselves. An operator (later: Nozy Guardian) must unbond / withdraw when those events fire.
- Early 10% is an **attestation**. The wallet must actually send 10% to the donation UA when it spends the note.

## License

MIT — see [LICENSE](LICENSE).
