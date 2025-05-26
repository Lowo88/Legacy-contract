import { ethers } from 'ethers';
import { parseUnits, formatUnits, parseEther, keccak256 } from 'ethers';
import { AbiCoder } from 'ethers';

export class TokenUtils {
    // Constants
    private static readonly DECIMALS = 18;
    private static readonly TOTAL_SUPPLY = BigInt('13088000000000000000000000'); // 13,088,000 LGC
    private static readonly PRICE_PEG = parseEther('1'); // 1 ETH
    private static readonly abiCoder = new AbiCoder();

    /**
     * Convert a human-readable amount to token units
     * @param amount Amount in human-readable format (e.g., 1.5)
     * @returns Amount in token units (wei)
     */
    static toTokenUnits(amount: number | string): bigint {
        return parseUnits(amount.toString(), this.DECIMALS);
    }

    /**
     * Convert token units to human-readable amount
     * @param amount Amount in token units (wei)
     * @returns Amount in human-readable format
     */
    static fromTokenUnits(amount: bigint): string {
        return formatUnits(amount, this.DECIMALS);
    }

    /**
     * Calculate the price in ETH for a given amount of tokens
     * @param tokenAmount Amount of tokens
     * @returns Price in ETH
     */
    static calculatePrice(tokenAmount: bigint): bigint {
        return (tokenAmount * this.PRICE_PEG) / parseEther('1');
    }

    /**
     * Calculate the amount of tokens for a given ETH amount
     * @param ethAmount Amount of ETH
     * @returns Amount of tokens
     */
    static calculateTokenAmount(ethAmount: bigint): bigint {
        return (ethAmount * parseEther('1')) / this.PRICE_PEG;
    }

    /**
     * Calculate the percentage of total supply
     * @param amount Amount of tokens
     * @returns Percentage as a decimal (e.g., 0.5 for 50%)
     */
    static calculatePercentage(amount: bigint): number {
        return Number((amount * BigInt(10000)) / this.TOTAL_SUPPLY) / 10000;
    }

    /**
     * Format a token amount with appropriate units
     * @param amount Amount in token units
     * @param decimals Number of decimal places to show
     * @returns Formatted string
     */
    static formatAmount(amount: bigint, decimals: number = 2): string {
        const formatted = this.fromTokenUnits(amount);
        const [whole, fraction] = formatted.split('.');
        return `${whole}.${fraction.slice(0, decimals)}`;
    }

    /**
     * Calculate the minimum amount for a valid transfer
     * @returns Minimum amount in token units
     */
    static getMinimumTransferAmount(): bigint {
        return parseUnits('0.000001', this.DECIMALS);
    }

    /**
     * Calculate the maximum amount that can be transferred
     * @returns Maximum amount in token units
     */
    static getMaximumTransferAmount(): bigint {
        return this.TOTAL_SUPPLY;
    }

    /**
     * Check if an amount is within valid transfer limits
     * @param amount Amount to check
     * @returns Boolean indicating if amount is valid
     */
    static isValidTransferAmount(amount: bigint): boolean {
        return amount >= this.getMinimumTransferAmount() && 
               amount <= this.getMaximumTransferAmount();
    }

    /**
     * Calculate the fee for a transfer
     * @param amount Transfer amount
     * @param feeRate Fee rate in basis points (e.g., 10 for 0.1%)
     * @returns Fee amount in token units
     */
    static calculateTransferFee(amount: bigint, feeRate: number): bigint {
        return (amount * BigInt(feeRate)) / BigInt(10000);
    }

    /**
     * Calculate the amount after fees
     * @param amount Original amount
     * @param feeRate Fee rate in basis points
     * @returns Amount after fees
     */
    static calculateAmountAfterFees(amount: bigint, feeRate: number): bigint {
        const fee = this.calculateTransferFee(amount, feeRate);
        return amount - fee;
    }

    /**
     * Generate a unique token ID for an NFT
     * @param owner Owner address
     * @param nonce Nonce value
     * @returns Token ID
     */
    static generateTokenId(owner: string, nonce: number): string {
        return keccak256(
            this.abiCoder.encode(
                ['address', 'uint256'],
                [owner, nonce]
            )
        );
    }

    /**
     * Calculate the vesting schedule
     * @param totalAmount Total amount to vest
     * @param duration Duration in seconds
     * @param cliffDuration Cliff duration in seconds
     * @returns Array of vesting amounts and timestamps
     */
    static calculateVestingSchedule(
        totalAmount: bigint,
        duration: number,
        cliffDuration: number
    ): { amount: bigint; timestamp: number }[] {
        const schedule: { amount: bigint; timestamp: number }[] = [];
        const now = Math.floor(Date.now() / 1000);
        
        // Add cliff
        if (cliffDuration > 0) {
            schedule.push({
                amount: BigInt(0),
                timestamp: now + cliffDuration
            });
        }

        // Add vesting periods
        const periods = 12; // Monthly vesting
        const periodDuration = (duration - cliffDuration) / periods;
        const periodAmount = totalAmount / BigInt(periods);

        for (let i = 1; i <= periods; i++) {
            schedule.push({
                amount: periodAmount,
                timestamp: now + cliffDuration + (periodDuration * i)
            });
        }

        return schedule;
    }
} 