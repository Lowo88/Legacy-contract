import { ethers } from 'ethers';
import { Halo2Prover } from './halo2-prover';
import { ProofTypes } from './types';

export class LegacyProofGenerator {
    private prover: Halo2Prover;
    private provider: ethers.providers.Provider;
    private contract: ethers.Contract;

    constructor(
        contractAddress: string,
        provider: ethers.providers.Provider,
        abi: any[]
    ) {
        this.provider = provider;
        this.contract = new ethers.Contract(contractAddress, abi, provider);
        this.prover = new Halo2Prover();
    }

    async generateShieldedTransferProof(
        nullifier: string,
        commitment: string,
        amount: bigint
    ): Promise<ProofTypes.ShieldedTransferProof> {
        const publicInputs = [
            ethers.utils.hexZeroPad(nullifier, 32),
            ethers.utils.hexZeroPad(commitment, 32),
            ethers.utils.hexZeroPad(amount.toString(16), 32)
        ];

        const proof = await this.prover.generateShieldedTransferProof(
            nullifier,
            commitment,
            amount
        );

        return {
            proofId: ethers.utils.keccak256(
                ethers.utils.concat([nullifier, commitment, amount.toString()])
            ),
            publicInputs,
            proof
        };
    }

    async generateViewingKeyProof(
        owner: string,
        viewingKey: string
    ): Promise<ProofTypes.ViewingKeyProof> {
        const publicInputs = [
            ethers.utils.hexZeroPad(owner, 32),
            ethers.utils.hexZeroPad(viewingKey, 32)
        ];

        const proof = await this.prover.generateViewingKeyProof(
            owner,
            viewingKey
        );

        return {
            proofId: ethers.utils.keccak256(
                ethers.utils.concat([owner, viewingKey])
            ),
            publicInputs,
            proof
        };
    }

    async generateEmergencyAccessProof(
        owner: string,
        contact: string,
        accessLevel: number
    ): Promise<ProofTypes.EmergencyAccessProof> {
        const publicInputs = [
            ethers.utils.hexZeroPad(owner, 32),
            ethers.utils.hexZeroPad(contact, 32),
            ethers.utils.hexZeroPad(accessLevel.toString(16), 32)
        ];

        const proof = await this.prover.generateEmergencyAccessProof(
            owner,
            contact,
            accessLevel
        );

        return {
            proofId: ethers.utils.keccak256(
                ethers.utils.concat([owner, contact, accessLevel.toString()])
            ),
            publicInputs,
            proof
        };
    }

    async submitProof(
        proof: ProofTypes.Proof,
        signer: ethers.Signer
    ): Promise<ethers.ContractTransaction> {
        const contractWithSigner = this.contract.connect(signer);
        return contractWithSigner.generateProof(
            proof.proofId,
            proof.publicInputs,
            proof.proof
        );
    }

    async verifyProof(
        proof: ProofTypes.Proof,
        signer: ethers.Signer
    ): Promise<boolean> {
        const contractWithSigner = this.contract.connect(signer);
        return contractWithSigner.verifyProof(
            proof.proofId,
            proof.publicInputs,
            proof.proof
        );
    }
} 