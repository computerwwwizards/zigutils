import type { PreProcessDependencyContainerWithUse } from '@computerwwwizards/dependency-injection'
import { type ContainerCtx } from './types'

export interface IApiClient {
  // TODO: Define service interface
}

declare module './types' {
  interface ServicesList {
    apiClient: IApiClient
  }
}

export default function registerApiClient(
  container: ContainerCtx
) {
  container.bind('apiClient', {
    // TODO: Implement service registration
  })
}

export function mock(
  container: ContainerCtx
) {
  container.bind('apiClient', {
    // TODO: Implement mock service registration
  })
}

registerApiClient.mock = mock
