import type { PreProcessDependencyContainerWithUse } from '@computerwwwizards/dependency-injection'
import { type ContainerCtx } from './types'

export interface IAuthProvider {
  // TODO: Define service interface
}

declare module './types' {
  interface ServicesList {
    auth_service: IAuthProvider
  }
}

export default function registerAuthService(
  container: ContainerCtx
) {
  container.bind('auth_service', {
    // TODO: Implement service registration
  })
}

export function mock(
  container: ContainerCtx
) {
  container.bind('auth_service', {
    // TODO: Implement mock service registration
  })
}

registerAuthService.mock = mock
