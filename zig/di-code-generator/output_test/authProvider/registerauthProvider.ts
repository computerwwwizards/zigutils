import type { PreProcessDependencyContainerWithUse } from '@computerwwwizards/dependency-injection'
import { type ContainerCtx } from './types'

export interface IAuthProvider {
  // TODO: Define service interface
}

declare module './types' {
  interface ServicesList {
    authProvider: IAuthProvider
  }
}

export default function registerAuthProvider(
  container: ContainerCtx
) {
  container.bind('authProvider', {
    // TODO: Implement service registration
  })
}

export function mock(
  container: ContainerCtx
) {
  container.bind('authProvider', {
    // TODO: Implement mock service registration
  })
}

registerAuthProvider.mock = mock
