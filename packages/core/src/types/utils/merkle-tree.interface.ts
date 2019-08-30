import { BigNumber } from '../number'

export interface MerkleTreeNode {
  key: BigNumber
  hash: Buffer
  value: Buffer
}

export interface MerkleTreeInclusionProof {
  key: BigNumber
  value: Buffer
  siblings: Buffer[]
}

export interface MerkleTree {
  /**
   * Gets the root hash for this tree.
   *
   * @returns The root hash.
   */
  getRootHash(): Promise<Buffer>

  /**
   * Updates the provided key in the Merkle Tree to have the value as data,
   * including all ancestors' hashes that result from this modification.
   *
   * @param key The key to update
   * @param value The new value
   * @return true if the update succeeded, false if we're missing the intermediate nodes / siblings required for this
   */
  update(key: BigNumber, value: Buffer): Promise<boolean>

  /* TODO when we need it
   * getMerkleProof(key: BigNumber, value: Buffer): Promise<MerkleTreeInclusionProof>
   */

  /**
   * Gets the leaf data at the provided key in the tree, if any exists.
   *
   * @param leafKey The key of the leaf to fetch
   * @param rootHash: The optional root hash if root verification is desired
   * @returns The value at the key if one exists, else undefined
   */
  getLeaf(leafKey: BigNumber, rootHash?: Buffer): Promise<Buffer>
}

export interface SparseMerkleTree extends MerkleTree {
  /**
   * Verifies that the provided inclusion proof and stores the
   * associated siblings for future updates / calculations.
   *
   * @param inclusionProof The inclusion proof in question
   * @return true if the proof was valid (and thus stored), false otherwise
   */
  verifyAndStore(inclusionProof: MerkleTreeInclusionProof): Promise<boolean>
}
