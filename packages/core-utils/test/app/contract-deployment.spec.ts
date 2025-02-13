import { should } from '../setup'

/* External Imports */
import { createMockProvider, getWallets } from 'ethereum-waffle'
import { ContractFactory, Wallet } from 'ethers-v4'
import { Provider } from 'ethers-v4/providers'

/* Internal Imports */
import { getDeployedContractAddress } from '../../src/app'

const dummyContractFactory = (wallet): ContractFactory => {
  // Generated by Remix
  const emptyContractAbi = ['constructor()']
  const emptyContractBytecode =
    '6080604052348015600f57600080fd5b50606c80601d6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c806326121ff014602d575b600080fd5b60336035565b005b56fea265627a7a723158205942af3e61207ff648ab4e4c2c1239bc0adf44f657e8436f08e6ea2ff336d38a64736f6c63430005100032'

  return new ContractFactory(emptyContractAbi, emptyContractBytecode, wallet)
}

describe('Contract deployment', () => {
  let provider: Provider
  let wallet: Wallet

  beforeEach(async () => {
    provider = createMockProvider()
    wallet = getWallets(provider)[0]
  })

  describe('getDeployedContractAddress', () => {
    it('should return the first deployed contract if one has been deployed', async () => {
      const factory = dummyContractFactory(wallet)
      const contract = await factory.deploy()
      await contract.deployed()
      const result = await getDeployedContractAddress(
        0,
        provider,
        wallet.address
      )
      result.should.eq(contract.address)
    })

    it('should return null if the address has not yet deployed a contract', async () => {
      const factory = dummyContractFactory(wallet)
      const result = await getDeployedContractAddress(
        0,
        provider,
        wallet.address
      )
      should.not.exist(result)
    })
  })
})
