export namespace ProofTypes {
    export interface Proof {
        proofId: string;
        publicInputs: string[];
        proof: string;
    }

    export interface ShieldedTransferProof extends Proof {
        nullifier: string;
        commitment: string;
        amount: bigint;
    }

    export interface ViewingKeyProof extends Proof {
        owner: string;
        viewingKey: string;
    }

    export interface EmergencyAccessProof extends Proof {
        owner: string;
        contact: string;
        accessLevel: number;
    }

    export interface ProofVerificationResult {
        isValid: boolean;
        error?: string;
    }

    export interface ProofGenerationOptions {
        timeout?: number;
        maxRetries?: number;
        retryDelay?: number;
    }
} 