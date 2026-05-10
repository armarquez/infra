# Incus Instance Management

VM/container management for testing infrastructure changes with snapshot-based rollback.

## Key Features

- **Snapshot Management**: Create, restore, and list snapshots for instant rollback
- **Instance Lifecycle**: Automated starting, stopping, and health checking
- **Console Access**: Direct VGA console access for debugging
- **Integration**: Works seamlessly with image building and Ansible testing

## Quick Commands

```bash
just attach HOST              # Attach to instance console (VGA)
just snapshot HOST NAME       # Create named snapshot
just restore HOST NAME        # Restore to named snapshot
just snapshot-initial HOST    # Create 'clean' baseline snapshot
just snapshot-timestamp HOST  # Create timestamped snapshot
just list-snapshots HOST      # List all snapshots for instance
```

## Testing Workflow Integration

```bash
# Create baseline for testing
just snapshot-initial phoenix

# Test changes
just ../ansible/test phoenix

# Quick rollback to clean state
just restore phoenix clean

# Repeat testing with modified playbooks...
```

## References

- [Incus Getting Started](https://linuxcontainers.org/incus/docs/main/tutorial/first_steps/)
- [Community Images](https://github.com/f-bn/incus-images/tree/main)
- [Distrobuilder Documentation](https://github.com/lxc/distrobuilder/blob/main/doc/index.md)
