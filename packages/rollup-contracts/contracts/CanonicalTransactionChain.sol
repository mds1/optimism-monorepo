pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

/* Internal Imports */
import {DataTypes as dt} from "./DataTypes.sol";
import {RollupMerkleUtils} from "./RollupMerkleUtils.sol";
import {L1ToL2TransactionQueue} from "./L1ToL2TransactionQueue.sol";

contract CanonicalTransactionChain {
  // The Rollup Merkle Tree library (currently a contract for ease of testing)
  RollupMerkleUtils merkleUtils;
  address public sequencer;

  // How many elements in total have been appended
  uint public cumulativeNumElements;
  // List of batch header hashes
  bytes32[] public batches;
  uint public latestOVMTimestamp = 0;
  uint sequencerLivenessAssumption;
  L1ToL2TransactionQueue public l1ToL2Queue;

  constructor(
    address _rollupMerkleUtilsAddress,
    address _sequencer,
    address _l1ToL2TransactionPasserAddress
  ) public {
    merkleUtils = RollupMerkleUtils(_rollupMerkleUtilsAddress);
    sequencer = _sequencer;
    l1ToL2Queue = new L1ToL2TransactionQueue(_rollupMerkleUtilsAddress, _l1ToL2TransactionPasserAddress, address(this));
    sequencerLivenessAssumption = 100000000000000000000000000; // TODO parameterize this
  }

  // for testing: returns length of batch list
  function getBatchsLength() public view returns (uint) {
    return batches.length;
  }

  function hashBatchHeader(
    dt.TxChainBatchHeader memory _batchHeader
  ) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(
      _batchHeader.timestamp,
      _batchHeader.isL1ToL2Tx,
      _batchHeader.elementsMerkleRoot,
      _batchHeader.numElementsInBatch,
      _batchHeader.cumulativePrevElements
    ));
  }

  function authenticateAppend(address _sender) public view returns (bool) {
    return _sender == sequencer;
  }

  function appendL1ToL2Batch() public {
    dt.TimestampedHash memory timestampedHash = l1ToL2Queue.getFrontBatch();
    uint timestamp = timestampedHash.timestamp;
    bytes32 elementsMerkleRoot = timestampedHash.txHash;
    if (timestamp + sequencerLivenessAssumption > now) {
      require(authenticateAppend(msg.sender), "Message sender does not have permission to append this batch");
    }
    require(timestamp >= latestOVMTimestamp, "Timestamps must be monotonically increasing");
    latestOVMTimestamp = timestamp;
    // // TODO require proposed timestamp is not too far away from currnt timestamp
    // // require dist(_timestamp, block.timestamp) < sequencerLivenessAssumption
    // // calculate batch header
    uint numElementsInBatch = 1;
    bytes32 batchHeaderHash = keccak256(abi.encodePacked(
      timestamp,
      true, // isL1ToL2Tx
      elementsMerkleRoot, 
      numElementsInBatch, // numElementsInBatch
      cumulativeNumElements // cumulativePrevElements
    ));
    // store batch header
    batches.push(batchHeaderHash);
    cumulativeNumElements++; // add a single tx
    l1ToL2Queue.dequeueBatch();
  }

  // appends to the current list of batches
  function appendTransactionBatch(bytes[] memory _txBatch, uint _timestamp) public {
    //Check that msg.sender is authorized to append
    require(authenticateAppend(msg.sender), "Message sender does not have permission to append a batch");
    require(_txBatch.length > 0, "Cannot submit an empty batch");
    require(_timestamp >= latestOVMTimestamp, "timestamps must monotonically increase");
    latestOVMTimestamp = _timestamp;
    // require dist(_timestamp, batch.timestamp) < sequencerLivenessAssumption
    // require(L1ToL2Queue.ageOfOldestQueuedBatch() < sequencerLivenessAssumption, "must process all L1->L2 batches older than liveness assumption before processing L2 batches.")
    // TODO check that this timestamp is before that of the oldest slowQueue and l1ToL2Queue batches

    // calculate batch header
    bytes32 batchHeaderHash = keccak256(abi.encodePacked(
      _timestamp,
      false, // isL1ToL2Tx
      merkleUtils.getMerkleRoot(_txBatch), // elementsMerkleRoot
      _txBatch.length, // numElementsInBatch
      cumulativeNumElements // cumulativeNumElements
    ));
    // store batch header
    batches.push(batchHeaderHash);
    // update cumulative elements
    cumulativeNumElements += _txBatch.length;
  }

  // verifies an element is in the current list at the given position
  function verifyElement(
     bytes memory _element, // the element of the list being proven
     uint _position, // the position in the list of the element being proven
     dt.ElementInclusionProof memory _inclusionProof  // inclusion proof in the rollup batch
  ) public view returns (bool) {
    // For convenience, store the batchHeader
    dt.TxChainBatchHeader memory batchHeader = _inclusionProof.batchHeader;
    // make sure absolute position equivalent to relative positions
    if(_position != _inclusionProof.indexInBatch +
      batchHeader.cumulativePrevElements)
      return false;

    // verify elementsMerkleRoot
    if (!merkleUtils.verify(
      batchHeader.elementsMerkleRoot,
      _element,
      _inclusionProof.indexInBatch,
      _inclusionProof.siblings
    )) return false;
    //compare computed batch header with the batch header in the list.
    return hashBatchHeader(batchHeader) == batches[_inclusionProof.batchIndex];
  }
}
