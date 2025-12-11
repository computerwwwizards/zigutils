import type { PreProcessDependencyContainerWithUse } from '@computerwwwizards/dependency-injection'
import { type ContainerCtx } from './types'

export interface IUserService {
  // TODO: Define service interface
}

declare module './types' {
  interface ServicesList {
    userService: IUserService
  }
}

export default function registerUserService(
  container: ContainerCtx
) {
  container.bind('userService', {
    // TODO: Implement service registration
  })
}

export function mock(
  container: ContainerCtx
) {
  container.bind('userService', {
    // TODO: Implement mock service registration
  })
}

registerUserService.mock = mock
