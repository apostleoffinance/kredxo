export const vaultAbi = [
  {
    type: "function",
    name: "deposit",
    stateMutability: "nonpayable",
    inputs: [{ name: "assets", type: "uint256" }],
    outputs: [{ name: "shares", type: "uint256" }],
  },
  {
    type: "function",
    name: "totalAssets",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "allocatedCredit",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "utilizedCredit",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const usdcAbi = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const accountAbi = [
  {
    type: "function",
    name: "executeTrade",
    stateMutability: "nonpayable",
    inputs: [
      { name: "market", type: "address" },
      { name: "side", type: "uint8" },
      { name: "size", type: "uint256" },
      { name: "leverage", type: "uint256" },
      { name: "price", type: "uint256" },
    ],
    outputs: [{ name: "id", type: "uint256" }],
  },
  {
    type: "function",
    name: "usedCredit",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "creditLimit",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const controllerAbi = [
  {
    type: "function",
    name: "applyPolicy",
    stateMutability: "nonpayable",
    inputs: [
      { name: "trader", type: "address" },
      { name: "creditLimit", type: "uint256" },
      { name: "maxLeverage", type: "uint256" },
      { name: "dailyLossLimit", type: "uint256" },
      { name: "validFrom", type: "uint256" },
      { name: "validUntil", type: "uint256" },
      { name: "riskLevel", type: "uint8" },
      { name: "markets", type: "address[]" },
      { name: "limits", type: "uint256[]" },
    ],
    outputs: [],
  },
] as const;
