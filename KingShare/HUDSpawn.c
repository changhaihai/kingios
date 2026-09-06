#include <spawn.h>
#include <sys/types.h>

extern char **environ;

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1

extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t *restrict, uid_t, uint32_t) __attribute__((weak_import));
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t *restrict, uid_t) __attribute__((weak_import));
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t *restrict, uid_t) __attribute__((weak_import));

int hai_root_spawn(const char *executable, const char *state_path, pid_t *pid_out) {
    posix_spawnattr_t attr;
    int rc = posix_spawnattr_init(&attr);
    if (rc != 0) return rc;

    if (posix_spawnattr_set_persona_np && posix_spawnattr_set_persona_uid_np && posix_spawnattr_set_persona_gid_np) {
        posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
        posix_spawnattr_set_persona_uid_np(&attr, 0);
        posix_spawnattr_set_persona_gid_np(&attr, 0);
    }

    const char *args[] = { executable, "--state", state_path, NULL };
    rc = posix_spawn(pid_out, executable, NULL, &attr, (char *const *)args, environ);
    posix_spawnattr_destroy(&attr);
    return rc;
}
